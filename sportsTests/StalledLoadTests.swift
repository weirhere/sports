import Foundation
import Testing
@testable import StatSide

/// Lets a test hold a fetch open and release it on cue.
private actor Gate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }
}

/// A provider that fails on demand, and can be made to hang first.
///
/// Games are beside the point here — an empty `Scoreboard` still marks its
/// days loaded, which is the only success this suite needs.
private final class FailingStub: ScoresProviding, @unchecked Sendable {
    nonisolated let league: League
    var failure: Error?
    let gate: Gate?

    init(league: League, failure: Error? = nil, gate: Gate? = nil) {
        self.league = league
        self.failure = failure
        self.gate = gate
    }

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        throw ESPNError.invalidURL
    }

    func scoreboard(days: ClosedRange<Date>,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        await gate?.wait()
        if let failure { throw failure }
        return Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 1,
                          weeks: [], games: [])
    }

    func rankings(year: Int?) async throws -> [Poll] { [] }
    func conferences(in division: Conference.Division) async throws -> [ConferenceTeams] { [] }
    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] { [] }
    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game] { [] }
    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        TeamSchedule(team: nil, record: nil, standing: nil, year: year, games: [])
    }
    func gameSummary(eventId: String) async throws -> GameSummary { throw ESPNError.invalidURL }
}

/// Every league backed by the same stub. A *total* failure is the case that
/// stranded the user, so that is what these build.
@MainActor
private func makeStalled(failure: Error? = nil,
                         gate: Gate? = nil) -> (LeagueScoreboards, [FailingStub]) {
    var stubs: [FailingStub] = []
    let stores: [League: ScoreboardStore] = Dictionary(
        uniqueKeysWithValues: League.allCases.map { league in
            let stub = FailingStub(league: league, failure: failure, gate: gate)
            stubs.append(stub)
            return (league, ScoreboardStore(league: league, client: stub))
        })
    return (LeagueScoreboards(stores: stores), stubs)
}

/// A day that never lands must say so.
///
/// The screen used to read every unwritten day as "still loading", so a
/// failed fetch sat under the skeleton forever with no message and no way
/// to retry — the 2026-09-17 field report ("why are no games showing up on
/// any day?"). `isStalled(on:)` is the distinction that fixes it, and these
/// pin both halves: a dead end is reported, and a load still in flight is
/// never mistaken for one.
@MainActor
struct StalledLoadTests {

    @Test func aFailedFirstLoadIsStalledAndSaysWhy() async {
        let (scoreboards, _) = makeStalled(failure: URLError(.notConnectedToInternet))
        await scoreboards.loadInitial()

        let day = scoreboards.selectedDay
        #expect(!scoreboards.isLoaded(day))
        // The whole point: a day with nothing in it and nothing coming is a
        // dead end, not a wait, and the screen can now tell them apart.
        #expect(scoreboards.isStalled(on: day))
        #expect(scoreboards.lastError == "No connection.")
    }

    @Test func nothingIsStalledBeforeTheFirstLoad() {
        let (scoreboards, _) = makeStalled()
        // The first frame renders before `.task` runs. Treating that as a
        // failure would flash an error on every cold launch.
        #expect(!scoreboards.hasAttemptedLoad)
        #expect(!scoreboards.isStalled(on: scoreboards.selectedDay))
    }

    @Test func aNoOpDivisionsChangeIsNotAnAttempt() async {
        let (scoreboards, _) = makeStalled(failure: URLError(.timedOut))
        // ScoresScreen runs this on every appear, ahead of the launch
        // fetch, and it returns instantly when nothing changed. Counting it
        // as an attempt would stall the very first frame.
        await scoreboards.select(divisions: [.fbs])
        #expect(!scoreboards.hasAttemptedLoad)
        #expect(!scoreboards.isStalled(on: scoreboards.selectedDay))
    }

    @Test func aLoadInFlightIsNotStalled() async {
        let gate = Gate()
        let (scoreboards, _) = makeStalled(failure: URLError(.timedOut), gate: gate)

        let load = Task { await scoreboards.loadInitial() }
        var spins = 0
        while !scoreboards.isLoading, spins < 10_000 {
            await Task.yield()
            spins += 1
        }
        #expect(scoreboards.isLoading)
        // Held open, nothing loaded — and still not a stall. Covering this
        // is the skeleton's one legitimate job.
        #expect(!scoreboards.isLoaded(scoreboards.selectedDay))
        #expect(!scoreboards.isStalled(on: scoreboards.selectedDay))

        await gate.open()
        await load.value
        #expect(scoreboards.isStalled(on: scoreboards.selectedDay))
    }

    @Test func aLoadedDayIsNeverStalledEvenWithNoGames() async {
        let (scoreboards, _) = makeStalled()
        await scoreboards.loadInitial()

        let day = scoreboards.selectedDay
        #expect(scoreboards.isLoaded(day))
        // An empty day says "No games today"; only an unloaded one is a
        // dead end.
        #expect(!scoreboards.isStalled(on: day))
        #expect(scoreboards.lastError == nil)
    }

    @Test func retryClearsTheStall() async {
        let (scoreboards, stubs) = makeStalled(failure: URLError(.networkConnectionLost))
        await scoreboards.loadInitial()
        #expect(scoreboards.isStalled(on: scoreboards.selectedDay))

        // What the Retry button does. It has to reach the network even
        // though no window ever completed — the store-level `refresh()`
        // keys off a window centre that a failed first load never sets.
        for stub in stubs { stub.failure = nil }
        await scoreboards.refresh()

        #expect(!scoreboards.isStalled(on: scoreboards.selectedDay))
        #expect(scoreboards.isLoaded(scoreboards.selectedDay))
        #expect(scoreboards.lastError == nil)
    }

    // MARK: - What the failure says

    @Test func anHTTPFailureCarriesItsStatusCode() async {
        let (scoreboards, _) = makeStalled(failure: ESPNError.badStatus(403))
        await scoreboards.loadInitial()
        // ESPN's API is undocumented and can change without notice, so the
        // number is the difference between "they moved the endpoint" and
        // "your wifi is out".
        #expect(scoreboards.lastError == "The scoreboard is unavailable (403).")
    }

    @Test func anUnreadablePayloadSaysSoRatherThanBlamingTheNetwork() async {
        let corrupt = DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "unexpected shape")
        )
        let (scoreboards, _) = makeStalled(failure: corrupt)
        await scoreboards.loadInitial()
        #expect(scoreboards.lastError == "Couldn't read the scoreboard.")
    }
}
