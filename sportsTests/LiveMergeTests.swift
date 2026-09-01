import Foundation
import Testing
@testable import StatSide

private func competitor(_ name: String, score: Int?, isHome: Bool) -> Competitor {
    Competitor(
        team: Team(id: name, location: name, name: nil, abbreviation: nil,
                   displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil),
        score: score, record: nil, rank: nil, isHome: isHome, winner: nil
    )
}

private func game(_ id: String, status: GameStatus, away: Int?, home: Int?) -> Game {
    Game(id: id, date: nil, name: nil, shortName: nil, weekNumber: 1, status: status,
         home: competitor("Tennessee", score: home, isHome: true),
         away: competitor("Georgia", score: away, isHome: false),
         broadcast: nil)
}

private let liveQ3 = GameStatus.live(displayClock: "5:24", period: 3, detail: nil,
                                     phase: .playing, possessionTeamId: nil)

/// The one live merge every non-polling surface renders through — a team's
/// schedule and a conference's season slate. Written twice and fixed once
/// (TeamPage's dashed scores, 2026-08-29, while ConferencePage's Games tab
/// kept freezing live games at page-open), so it now has one home.
@Suite struct LiveMergeTests {
    @Test func scoreboardCopyReplacesTheStaleSnapshot() {
        let stale = game("g1", status: .pre(detail: nil), away: nil, home: nil)
        let live = game("g1", status: liveQ3, away: 14, home: 7)
        let merged = Game.merging([stale], withLive: [live])
        #expect(merged.count == 1)
        #expect(merged[0].isLive)
        #expect(merged[0].away.score == 14)
    }

    @Test func gamesTheScoreboardHasntLoadedKeepTheirSnapshot() {
        // Any week but the selected one — and past seasons entirely.
        let ownWeek = game("g2", status: .final(detail: "Final"), away: 21, home: 28)
        let merged = Game.merging([ownWeek], withLive: [game("g1", status: liveQ3, away: 3, home: 0)])
        #expect(merged.map(\.id) == ["g2"])
        #expect(merged[0].away.score == 21)
    }

    @Test func orderIsPreservedAndAnEmptyBoardIsIdentity() {
        let slate = [game("a", status: .pre(detail: nil), away: nil, home: nil),
                     game("b", status: liveQ3, away: 7, home: 7),
                     game("c", status: .final(detail: "Final"), away: 31, home: 10)]
        #expect(Game.merging(slate, withLive: []).map(\.id) == ["a", "b", "c"])
        let merged = Game.merging(slate, withLive: [game("b", status: liveQ3, away: 10, home: 7)])
        #expect(merged.map(\.id) == ["a", "b", "c"])
        #expect(merged[1].away.score == 10)
    }

    @Test func singleGameFormMatchesTheArrayForm() {
        let stale = game("g1", status: .pre(detail: nil), away: nil, home: nil)
        let live = game("g1", status: liveQ3, away: 14, home: 7)
        #expect(Game.merging(stale, withLive: [live]).away.score == 14)
        #expect(Game.merging(stale, withLive: []).away.score == nil)
    }

    /// A live game going final on the scoreboard must reach these pages
    /// too — the merge is not live-only, it is "the scoreboard knows more".
    @Test func aFinalOnTheScoreboardReplacesALiveSnapshot() {
        let stale = game("g1", status: liveQ3, away: 14, home: 7)
        let ended = game("g1", status: .final(detail: "Final"), away: 14, home: 21)
        let merged = Game.merging(stale, withLive: [ended])
        #expect(!merged.isLive)
        #expect(merged.home.score == 21)
    }
}
