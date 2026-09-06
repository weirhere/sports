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
