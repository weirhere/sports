import Foundation
import Testing
@testable import StatSide

private func team(_ id: String) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: "T\(id)",
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 8)
}

private func game(_ id: String, home: String, away: String,
                  status: GameStatus, date: Date?) -> Game {
    Game(id: id, date: date, name: nil, shortName: nil, weekNumber: 1, status: status,
         home: Competitor(team: team(home), score: nil, record: nil, rank: nil, isHome: true, winner: nil),
         away: Competitor(team: team(away), score: nil, record: nil, rank: nil, isHome: false, winner: nil),
         broadcast: nil)
}

@Suite struct GameSelectionTests {
    /// 6pm on a fixed day, so every offset below lands where the assertion
    /// expects it in any time zone the tests run in — the selection rules
    /// read the local calendar.
    private let now = Calendar.current.date(
        bySettingHour: 18, minute: 0, second: 0,
        of: Date(timeIntervalSince1970: 1_760_000_000)
    ) ?? Date(timeIntervalSince1970: 1_760_000_000)

    @Test func liveBeatsUpcomingBeatsFinal() {
        let games = [
            game("final", home: "1", away: "9", status: .final(detail: "Final"),
                 date: now.addingTimeInterval(-3 * 3600)),
            game("pre", home: "1", away: "8", status: .pre(detail: nil),
                 date: now.addingTimeInterval(3600)),
            game("live", home: "1", away: "7", status: .live(displayClock: "5:00", period: 2, detail: nil, phase: .playing, possessionTeamId: nil),
                 date: now.addingTimeInterval(-3600)),
        ]
        let picked = GameSelection.relevantGames(in: games, followedKeys: ["cfb:1"], limit: 3, now: now)
        #expect(picked.map(\.id) == ["live", "pre", "final"])
    }

    @Test func mostRecentFinalWinsAmongFinals() {
        let games = [
            game("early", home: "1", away: "9", status: .final(detail: "Final"),
                 date: now.addingTimeInterval(-8 * 3600)),
            game("late", home: "1", away: "8", status: .final(detail: "Final"),
                 date: now.addingTimeInterval(-2 * 3600)),
        ]
        let picked = GameSelection.relevantGames(in: games, followedKeys: ["cfb:1"], limit: 1, now: now)
        #expect(picked.map(\.id) == ["late"])
    }

    @Test func unfollowedGamesAreInvisible() {
        let games = [game("g", home: "1", away: "2", status: .pre(detail: nil), date: now)]
        #expect(GameSelection.relevantGames(in: games, followedKeys: ["cfb:99"], limit: 3, now: now).isEmpty)
        #expect(GameSelection.relevantGames(in: games, followedKeys: [], limit: 3, now: now).isEmpty)
    }

    @Test func limitHolds() {
        let games = (1...5).map {
            game("g\($0)", home: "1", away: "\($0 + 10)", status: .pre(detail: nil),
                 date: now.addingTimeInterval(Double($0) * 3600))
        }
        let picked = GameSelection.relevantGames(in: games, followedKeys: ["cfb:1"], limit: 3, now: now)
        #expect(picked.count == 3)
        #expect(picked.map(\.id) == ["g1", "g2", "g3"])
    }

    // MARK: - Fetch window

    /// The window has to reach next weekend for both leagues at once, and
    /// one day back so an overnight final is still in the payload while its
    /// grace runs.
    @Test func theFetchWindowSpansYesterdayToAFortnightOut() {
        let calendar = Calendar.current
        let window = GameSelection.fetchWindow(around: now)
        #expect(window.lowerBound == calendar.date(byAdding: .day, value: -1,
                                                   to: calendar.startOfDay(for: now)))
        #expect(window.upperBound == calendar.date(byAdding: .day, value: 14,
                                                   to: calendar.startOfDay(for: now)))
        // The reported scenario: a Saturday game six days out is in range,
        // and so is a bye week's fixture thirteen days out.
        #expect(window.contains(now.addingTimeInterval(6 * 24 * 3600)))
        #expect(window.contains(now.addingTimeInterval(13 * 24 * 3600)))
    }

    // MARK: - Yesterday clears

    /// The report: two college teams played Saturday and play again next
    /// Saturday, and on Sunday the widget was still showing Saturday's
    /// finals instead of the fixtures.
    @Test func yesterdaysFinalsMakeWayForNextWeek() {
        let yesterdayAfternoon = now.addingTimeInterval(-22 * 3600)
        let games = [
            game("yesterday", home: "1", away: "9", status: .final(detail: "Final"),
                 date: yesterdayAfternoon),
            game("saturday", home: "1", away: "8", status: .pre(detail: nil),
                 date: now.addingTimeInterval(6 * 24 * 3600)),
        ]
        let picked = GameSelection.relevantGames(in: games, followedKeys: ["cfb:1"], limit: 4, now: now)
        #expect(picked.map(\.id) == ["saturday"])
    }

    /// Today's result is the whole point of checking: it holds its slot even
    /// with a fixture on the board.
    @Test func todaysFinalKeepsItsSlot() {
        let games = [
            game("earlier", home: "1", away: "9", status: .final(detail: "Final"),
                 date: now.addingTimeInterval(-5 * 3600)),
            game("next", home: "1", away: "8", status: .pre(detail: nil),
                 date: now.addingTimeInterval(6 * 24 * 3600)),
        ]
        let picked = GameSelection.relevantGames(in: games, followedKeys: ["cfb:1"], limit: 4, now: now)
        #expect(picked.map(\.id) == ["next", "earlier"])
    }

    /// A late kickoff files under the day it started, so a game that ends
    /// after midnight must not clear the instant it goes final.
    @Test func anOvernightFinalSurvivesTheDateChange() {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: now)
        // Kicked 10:30pm, final and read at 1:30am the next morning.
        let kickoff = midnight.addingTimeInterval(-90 * 60)
        let justAfterMidnight = midnight.addingTimeInterval(90 * 60)
        let overnight = [game("overnight", home: "1", away: "9",
                              status: .final(detail: "Final"), date: kickoff)]
        #expect(GameSelection.relevantGames(in: overnight, followedKeys: ["cfb:1"],
                                            limit: 4, now: justAfterMidnight).count == 1)
        // By breakfast it is history.
        let morning = midnight.addingTimeInterval(9 * 3600)
        #expect(GameSelection.relevantGames(in: overnight, followedKeys: ["cfb:1"],
                                            limit: 4, now: morning).isEmpty)
    }

    /// A live game is exempt: no clock heuristic gets to suppress the one
    /// thing the widget exists for.
    @Test func aLiveGameIsNeverSpent() {
        let stuck = game("live", home: "1", away: "9",
                         status: .live(displayClock: "2:00", period: 4, detail: nil,
                                       phase: .playing, possessionTeamId: nil),
                         date: now.addingTimeInterval(-30 * 3600))
        #expect(GameSelection.relevantGames(in: [stuck], followedKeys: ["cfb:1"],
                                            limit: 4, now: now).map(\.id) == ["live"])
    }

    /// A kickoff ESPN never flipped off `pre` would otherwise sort ahead of
    /// every real fixture — its "time until kickoff" is the most negative
    /// number on the board.
    @Test func aStaleUnflippedKickoffDoesNotOutrankRealFixtures() {
        let games = [
            game("ghost", home: "1", away: "9", status: .pre(detail: nil),
                 date: now.addingTimeInterval(-26 * 3600)),
            game("real", home: "1", away: "8", status: .pre(detail: nil),
                 date: now.addingTimeInterval(3600)),
        ]
        let picked = GameSelection.relevantGames(in: games, followedKeys: ["cfb:1"], limit: 4, now: now)
        #expect(picked.map(\.id) == ["real"])
    }

    /// Yesterday's cancellation clears on the same rule.
    @Test func yesterdaysCancellationClears() {
        let canceled = [game("canceled", home: "1", away: "9",
                             status: .other(detail: "Canceled"),
                             date: now.addingTimeInterval(-22 * 3600))]
        #expect(GameSelection.relevantGames(in: canceled, followedKeys: ["cfb:1"],
                                            limit: 4, now: now).isEmpty)
    }

    // MARK: - Refresh policy

    @Test func liveGamePolls15Minutes() {
        let live = [game("g", home: "1", away: "2",
                         status: .live(displayClock: nil, period: nil, detail: nil, phase: .playing, possessionTeamId: nil),
                         date: now)]
        #expect(GameSelection.nextRefresh(after: now, games: live) == now.addingTimeInterval(15 * 60))
    }

    @Test func imminentKickoffPullsRefreshEarlier() {
        let kickoff = now.addingTimeInterval(45 * 60)
        let pre = [game("g", home: "1", away: "2", status: .pre(detail: nil), date: kickoff)]
        // A minute after kickoff, so ESPN has flipped the game live.
        #expect(GameSelection.nextRefresh(after: now, games: pre) == kickoff.addingTimeInterval(60))
    }

    @Test func quietWeeksRefreshHourly() {
        let farOff = [game("g", home: "1", away: "2", status: .pre(detail: nil),
                           date: now.addingTimeInterval(72 * 3600))]
        #expect(GameSelection.nextRefresh(after: now, games: farOff) == now.addingTimeInterval(3600))
        #expect(GameSelection.nextRefresh(after: now, games: []) == now.addingTimeInterval(3600))
    }

    /// A result on screen expires at midnight, so the timeline asks then
    /// rather than on whichever hourly tick lands after it.
    @Test func aResultOnScreenRefreshesAtMidnight() {
        let calendar = Calendar.current
        let lateEvening = calendar.startOfDay(for: now).addingTimeInterval(23 * 3600 + 40 * 60)
        let final = [game("g", home: "1", away: "2", status: .final(detail: "Final"),
                          date: lateEvening.addingTimeInterval(-4 * 3600))]
        let tomorrow = calendar.date(byAdding: .day, value: 1,
                                     to: calendar.startOfDay(for: lateEvening))
        #expect(GameSelection.nextRefresh(after: lateEvening, games: final) == tomorrow)
    }

    /// Midnight is a ceiling, not a target: an hour before the day ends is
    /// still an hour away, so a board of fixtures keeps the hourly tick.
    @Test func fixturesOnlyKeepTheHourlyTick() {
        let calendar = Calendar.current
        let lateEvening = calendar.startOfDay(for: now).addingTimeInterval(23 * 3600 + 40 * 60)
        let pre = [game("g", home: "1", away: "2", status: .pre(detail: nil),
                        date: lateEvening.addingTimeInterval(5 * 24 * 3600))]
        #expect(GameSelection.nextRefresh(after: lateEvening, games: pre)
                    == lateEvening.addingTimeInterval(3600))
    }
}
