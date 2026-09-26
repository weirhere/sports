import Foundation
import Testing
@testable import StatSide

/// A provider shaped like ESPN's `dates=` request: it holds a season's
/// games and hands back the ones falling inside the requested range,
/// counting requests so the window's caching is observable.
private final class DayProvider: ScoresProviding, @unchecked Sendable {
    nonisolated let league: League
    private let games: [Game]
    /// Extra games that only appear when group 81 is asked for.
    private let fcsGames: [Game]
    private(set) var requests: [ClosedRange<Date>] = []
    private(set) var divisionsAsked: [Set<Conference.Division>] = []
    var shouldFail = false

    init(league: League = .collegeFootball, games: [Game], fcsGames: [Game] = []) {
        self.league = league
        self.games = games
        self.fcsGames = fcsGames
    }

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        throw ESPNError.invalidURL
    }

    func scoreboard(days: ClosedRange<Date>,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        requests.append(days)
        divisionsAsked.append(divisions)
        if shouldFail { throw URLError(.networkConnectionLost) }
        let calendar = Calendar.current
        let lower = calendar.startOfDay(for: days.lowerBound)
        let upper = calendar.date(byAdding: .day, value: 1,
                                  to: calendar.startOfDay(for: days.upperBound)) ?? days.upperBound
        var pool = games
        if divisions.contains(.fcs) { pool += fcsGames }
        return Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 1, weeks: [],
                          games: pool.filter { game in
                              guard let date = game.date else { return false }
                              return date >= lower && date < upper
                          })
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

private func team(_ id: String, conference: Int? = nil) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: conference)
}

/// Noon local, so a day's games can never drift into a neighbouring bucket
/// on a machine in any time zone.
private func day(_ offset: Int, from anchor: Date = Date(timeIntervalSince1970: 1_788_000_000)) -> Date {
    let calendar = Calendar.current
    let midnight = calendar.startOfDay(for: anchor)
    let shifted = calendar.date(byAdding: .day, value: offset, to: midnight) ?? midnight
    return calendar.date(byAdding: .hour, value: 12, to: shifted) ?? shifted
}

private func game(_ id: String, on date: Date?, live: Bool = false,
                  conference: Int? = nil) -> Game {
    Game(id: id, date: date, name: nil, shortName: nil, weekNumber: 1,
         status: live
            ? .live(displayClock: "5:00", period: 2, detail: nil, phase: .playing,
                    possessionTeamId: nil)
            : .pre(detail: nil),
         home: Competitor(team: team("h\(id)", conference: conference), score: nil,
                          record: nil, rank: nil, isHome: true, winner: nil),
         away: Competitor(team: team("a\(id)", conference: conference), score: nil,
                          record: nil, rank: nil, isHome: false, winner: nil),
         broadcast: nil)
}

@MainActor
@Suite struct ScoreboardStoreTests {

    // MARK: - The day window

    @Test func aWindowLoadBucketsGamesByLocalDay() async {
        let provider = DayProvider(games: [game("yesterday", on: day(-1)),
                                           game("today-a", on: day(0)),
                                           game("today-b", on: day(0)),
                                           game("tomorrow", on: day(1))])
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))

        #expect(store.games(on: day(-1)).map(\.id) == ["yesterday"])
        #expect(store.games(on: day(0)).map(\.id) == ["today-a", "today-b"])
        #expect(store.games(on: day(1)).map(\.id) == ["tomorrow"])
    }

    @Test func oneRequestCoversTheShownDayAndBothNeighbours() async {
        // The swipe's ±1 targets arrive with the day itself: a five-day
        // ESPN window, one request, no separate prefetch.
        let provider = DayProvider(games: [game("yesterday", on: day(-1)),
                                           game("today", on: day(0)),
                                           game("tomorrow", on: day(1))])
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))
        #expect(provider.requests.count == 1)

        let calendar = Calendar.current
        let request = try! #require(provider.requests.first)
        #expect(calendar.dateComponents([.day], from: request.lowerBound,
                                        to: request.upperBound).day == 4)

        // Both preview panes render from that one request — the swipe
        // never shows a skeleton for a neighbour.
        #expect(store.games(on: day(-1)).map(\.id) == ["yesterday"])
        #expect(store.games(on: day(1)).map(\.id) == ["tomorrow"])
    }

    @Test func committingToANeighbourWarmsTheNextOne() async {
        // Landing on tomorrow makes the day after it the new swipe target,
        // so the window re-centres — one request per day change, the same
        // budget the week strip spent per week change.
        let provider = DayProvider(games: [])
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))
        #expect(!store.isLoaded(day(2)))

        await store.load(around: day(1))
        #expect(provider.requests.count == 2)
        #expect(store.isLoaded(day(2)))
    }

    @Test func theOutermostWindowDaysAreNotRecordedAsLoaded() async {
        // ESPN reads `dates=` on the Eastern clock, so the far ends of the
        // window are a partial answer for most time zones. Recording them
        // as loaded would let a half-slate pass for a whole one.
        let store = ScoreboardStore(client: DayProvider(games: []))
        await store.load(around: day(0))

        #expect(store.isLoaded(day(-1)))
        #expect(store.isLoaded(day(0)))
        #expect(store.isLoaded(day(1)))
        #expect(!store.isLoaded(day(2)))
        #expect(!store.isLoaded(day(-2)))
    }

    @Test func steppingTwoDaysOnAsksAgain() async {
        let provider = DayProvider(games: [])
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))
        await store.load(around: day(2))
        #expect(provider.requests.count == 2)
    }

    @Test func forceRefetchesTheSameWindow() async {
        let provider = DayProvider(games: [])
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))
        await store.load(around: day(0))
        #expect(provider.requests.count == 1)

        await store.load(around: day(0), force: true)
        #expect(provider.requests.count == 2)
    }

    @Test func aFailedFetchKeepsLastGoodGamesAndReportsTheError() async {
        let provider = DayProvider(games: [game("g1", on: day(0))])
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))
        #expect(store.lastError == nil)

        provider.shouldFail = true
        await store.load(around: day(0), force: true)
        #expect(store.lastError != nil)
        #expect(store.games(on: day(0)).map(\.id) == ["g1"])

        provider.shouldFail = false
        await store.refresh()
        #expect(store.lastError == nil)
    }

    @Test func daysFarFromTheWindowAreEvicted() async {
        let provider = DayProvider(games: (-40...40).map { game("g\($0)", on: day($0)) })
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))
        #expect(store.isLoaded(day(0)))

        // Walk far enough that the original window falls outside the
        // cache radius; browsing a season must not accumulate it.
        for offset in stride(from: 2, through: 30, by: 2) {
            await store.load(around: day(offset))
        }
        #expect(store.isLoaded(day(30)))
        #expect(!store.isLoaded(day(0)))
    }

    @Test func boardGamesCoverTheWindowOnly() async {
        let provider = DayProvider(games: (-3...3).map { game("g\($0)", on: day($0)) })
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))

        // The fresher-copy source other screens merge against is the
        // window's three days, not every day ever browsed.
        #expect(Set(store.boardGames.map(\.id)) == ["g-1", "g0", "g1"])
    }

    @Test func liveGamesAreSeenAnywhereInTheWindow() async {
        let store = ScoreboardStore(client: DayProvider(games: [
            game("quiet", on: day(0)),
            game("live", on: day(1), live: true),
        ]))
        await store.load(around: day(0))

        // A followed game on tomorrow's slate still has to keep ticking.
        #expect(store.hasLiveGames)
        #expect(!store.hasLiveGames(on: day(0)))
        #expect(store.hasLiveGames(on: day(1)))
    }

    @Test func gamesWithNoKickoffDateAreNotPlacedOnADay() async {
        let store = ScoreboardStore(client: DayProvider(games: [game("tbd", on: nil)]))
        await store.load(around: day(0))
        #expect(store.games(on: day(0)).isEmpty)
    }

    // MARK: - Polling through kickoff

    private static let now = Date(timeIntervalSince1970: 1_790_000_000)
    private static let interval = Duration.seconds(30)

    private func kickoff(_ id: String, in seconds: TimeInterval, tbd: Bool = false,
                         status: GameStatus = .pre(detail: nil)) -> Game {
        let base = game(id, on: Self.now.addingTimeInterval(seconds))
        var copy = Game(id: base.id, date: base.date, name: nil, shortName: nil, weekNumber: 1,
                        status: status, home: base.home, away: base.away, broadcast: nil)
        copy.timeTBD = tbd
        return copy
    }

    private func delay(_ games: [Game]) -> Duration? {
        ScoreboardStore.nextPollDelay(for: games, now: Self.now, interval: Self.interval)
    }

    @Test func aLiveGamePollsAtTheInterval() {
        #expect(delay([game("live", on: Self.now, live: true)]) == Self.interval)
    }

    @Test func aKickoffInsideOneIntervalPollsAtTheInterval() {
        #expect(delay([kickoff("soon", in: 10)]) == Self.interval)
    }

    @Test func aLaterKickoffSleepsUntilKickoff() {
        #expect(delay([kickoff("later", in: 20 * 60), kickoff("evening", in: 6 * 3600)])
                == .seconds(20 * 60))
    }

    @Test func aGameStillPreGameAnHourPastKickoffKeepsPolling() {
        #expect(delay([kickoff("lagging", in: -3600)]) == Self.interval)
    }

    @Test func aGameStillPreGameFourHoursPastKickoffStopsPolling() {
        #expect(delay([kickoff("ghost", in: -4 * 3600)]) == nil)
    }

    @Test func aPlaceholderKickoffSchedulesNothing() {
        #expect(delay([kickoff("tbd", in: 60, tbd: true)]) == nil)
    }

    @Test func anAllFinalSlateStopsPolling() {
        #expect(delay([kickoff("done", in: -3600, status: .final(detail: nil))]) == nil)
    }

    /// The bug: a slate opened before kickoff never polled, so rows sat at
    /// their kickoff times until someone pulled to refresh.
    @Test func aPreGameSlatePollsWithoutAnotherLoad() async throws {
        let provider = DayProvider(games: [game("kicked", on: Date().addingTimeInterval(-600))])
        let store = ScoreboardStore(client: provider, pollInterval: .milliseconds(50))
        await store.load(around: Date())
        #expect(provider.requests.count == 1)
        try await Task.sleep(for: .milliseconds(400))
        store.stopPolling()
        #expect(provider.requests.count >= 3)
    }

    // MARK: - Finding a day worth showing

    @Test func firstDayWithGamesProbesForward() async {
        let store = ScoreboardStore(client: DayProvider(games: [game("opener", on: day(20))]))
        let found = await store.firstDayWithGames(from: day(0))
        #expect(found.map { Calendar.current.startOfDay(for: $0) }
                == Calendar.current.startOfDay(for: day(20)))
    }

    @Test func firstDayWithGamesGivesUpOnAnEmptyStretch() async {
        let store = ScoreboardStore(client: DayProvider(games: []))
        #expect(await store.firstDayWithGames(from: day(0), searchingDays: 28) == nil)
    }

    // MARK: - Divisions

    @Test func theStoreAsksForFBSOnlyUntilSomeoneOptsIn() async {
        let provider = DayProvider(games: [game("fbs", on: day(0))],
                                   fcsGames: [game("fcs", on: day(0))])
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))

        #expect(provider.divisionsAsked == [[.fbs]])
        #expect(store.games(on: day(0)).map(\.id) == ["fbs"])
    }

    @Test func aDivisionSwitchCannotServeTheStaleSlate() async {
        let provider = DayProvider(games: [game("fbs", on: day(0))],
                                   fcsGames: [game("fcs", on: day(0))])
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))

        await store.select(divisions: [.fbs, .fcs])
        #expect(store.divisions == [.fbs, .fcs])
        #expect(Set(store.games(on: day(0)).map(\.id)) == ["fbs", "fcs"])
        #expect(provider.divisionsAsked.last == [.fbs, .fcs])
    }

    @Test func settingTheSameDivisionsAsksNothing() async {
        let provider = DayProvider(games: [game("fbs", on: day(0))])
        let store = ScoreboardStore(client: provider)
        await store.load(around: day(0))
        let before = provider.requests.count

        await store.select(divisions: [.fbs])
        #expect(provider.requests.count == before)
    }

    @Test func divisionsNeededFollowTheFilterAndFollows() {
        #expect(ScoreboardStore.divisions(filter: nil, followedConferenceIds: []) == [.fbs])
        // 20 is an FCS conference in the registry; picking or following one
        // is the only thing that puts group 81 on the slate.
        #expect(ScoreboardStore.divisions(filter: .conference(.cfb(20)),
                                          followedConferenceIds: []).contains(.fcs))
        #expect(ScoreboardStore.divisions(filter: nil,
                                          followedConferenceIds: [.cfb(20)]).contains(.fcs))
        #expect(ScoreboardStore.divisions(filter: .conference(.cfb(8)),
                                          followedConferenceIds: []) == [.fbs])
    }
}

/// The 1s live poll asks only for the Eastern days with games in play
/// (2026-09-26), and patches those games into the slate by id.
@MainActor
@Suite struct LivePollTests {
    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func final(_ id: String, on date: Date) -> Game {
        let base = game(id, on: date)
        return Game(id: id, date: date, name: nil, shortName: nil, weekNumber: 1,
                    status: .final(detail: "Final"), home: base.home, away: base.away,
                    broadcast: nil)
    }

    private func live(_ id: String, clock: String, homeScore: Int?) -> Game {
        let base = game(id, on: Self.now)
        let home = Competitor(team: base.home.team, score: homeScore, record: nil, rank: nil,
                              isHome: true, winner: nil)
        return Game(id: id, date: Self.now, name: nil, shortName: nil, weekNumber: 1,
                    status: .live(displayClock: clock, period: 4, detail: nil, phase: .playing,
                                  possessionTeamId: nil),
                    home: home, away: base.away, broadcast: nil)
    }

    @Test func onlyGamesInPlayOrPastKickoffNameADay() {
        let games = [game("live", on: Self.now.addingTimeInterval(-3600), live: true),
                     game("late", on: Self.now.addingTimeInterval(-60)),
                     game("later", on: Self.now.addingTimeInterval(3600)),
                     final("done", on: Self.now.addingTimeInterval(-86_400 * 2))]
        let days = ScoreboardStore.liveDays(in: games, now: Self.now)
        let tokens = Set(days.map(DayFormat.espnToken(for:)))
        #expect(tokens == Set([DayFormat.espnToken(for: Self.now.addingTimeInterval(-3600)),
                               DayFormat.espnToken(for: Self.now.addingTimeInterval(-60))]))
        #expect(!tokens.contains(DayFormat.espnToken(for: Self.now.addingTimeInterval(-86_400 * 2))))
    }

    @Test func oneDateForEachEasternDay() {
        // Two live games an hour apart on one Eastern day ask once.
        let a = game("a", on: Self.now.addingTimeInterval(-7200), live: true)
        let b = game("b", on: Self.now.addingTimeInterval(-3600), live: true)
        let sameDay = DayFormat.espnToken(for: a.date!) == DayFormat.espnToken(for: b.date!)
        #expect(ScoreboardStore.liveDays(in: [a, b], now: Self.now).count == (sameDay ? 1 : 2))
        // Two live games on different Eastern days ask twice.
        let c = game("c", on: Self.now.addingTimeInterval(-86_400), live: true)
        #expect(ScoreboardStore.liveDays(in: [b, c], now: Self.now).count == 2)
    }

    @Test func nothingInPlayAsksForNothing() {
        let games = [game("later", on: Self.now.addingTimeInterval(3600)),
                     final("done", on: Self.now.addingTimeInterval(-3600))]
        #expect(ScoreboardStore.liveDays(in: games, now: Self.now).isEmpty)
    }

    @Test func patchingReplacesByIdAndKeepsTheRest() {
        let held = [live("g1", clock: "5:00", homeScore: 7),
                    game("g2", on: Self.now.addingTimeInterval(3600))]
        let fresh = ["g1": live("g1", clock: "4:10", homeScore: 14)]
        let patched = ScoreboardStore.patching(held, with: fresh)
        #expect(patched.count == 2)
        #expect(patched[0].home.score == 14)
        #expect(patched[1] == held[1])
    }

    @Test func patchingNeverStepsBackwards() {
        let held = [live("g1", clock: "0:58", homeScore: 29)]
        let stale = ["g1": live("g1", clock: "1:56", homeScore: 22)]
        let patched = ScoreboardStore.patching(held, with: stale)
        #expect(patched[0].status == held[0].status)
        #expect(patched[0].home.score == 29)
    }
}
