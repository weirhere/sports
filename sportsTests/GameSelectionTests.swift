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
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    @Test func liveBeatsUpcomingBeatsFinal() {
        let games = [
            game("final", home: "1", away: "9", status: .final(detail: "Final"),
                 date: now.addingTimeInterval(-3 * 3600)),
            game("pre", home: "1", away: "8", status: .pre(detail: nil),
                 date: now.addingTimeInterval(3600)),
            game("live", home: "1", away: "7", status: .live(displayClock: "5:00", period: 2, detail: nil, phase: .playing, possessionTeamId: nil),
                 date: now.addingTimeInterval(-3600)),
        ]
        let picked = GameSelection.relevantGames(in: games, followedIds: ["1"], limit: 3, now: now)
        #expect(picked.map(\.id) == ["live", "pre", "final"])
    }

    @Test func mostRecentFinalWinsAmongFinals() {
        let games = [
            game("early", home: "1", away: "9", status: .final(detail: "Final"),
                 date: now.addingTimeInterval(-8 * 3600)),
            game("late", home: "1", away: "8", status: .final(detail: "Final"),
                 date: now.addingTimeInterval(-2 * 3600)),
        ]
        let picked = GameSelection.relevantGames(in: games, followedIds: ["1"], limit: 1, now: now)
        #expect(picked.map(\.id) == ["late"])
    }

    @Test func unfollowedGamesAreInvisible() {
        let games = [game("g", home: "1", away: "2", status: .pre(detail: nil), date: now)]
        #expect(GameSelection.relevantGames(in: games, followedIds: ["99"], limit: 3, now: now).isEmpty)
        #expect(GameSelection.relevantGames(in: games, followedIds: [], limit: 3, now: now).isEmpty)
    }

    @Test func limitHolds() {
        let games = (1...5).map {
            game("g\($0)", home: "1", away: "\($0 + 10)", status: .pre(detail: nil),
                 date: now.addingTimeInterval(Double($0) * 3600))
        }
        let picked = GameSelection.relevantGames(in: games, followedIds: ["1"], limit: 3, now: now)
        #expect(picked.count == 3)
        #expect(picked.map(\.id) == ["g1", "g2", "g3"])
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
}
