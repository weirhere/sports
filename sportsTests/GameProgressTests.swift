import Foundation
import Testing
@testable import StatSide

private func competitor(_ name: String, score: Int?, isHome: Bool) -> Competitor {
    Competitor(
        team: Team(id: name, location: name, name: nil, abbreviation: nil,
                   displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil),
        score: score, record: nil, rank: isHome ? 5 : nil, isHome: isHome, winner: nil
    )
}

private func game(_ id: String, status: GameStatus, away: Int?, home: Int?) -> Game {
    Game(id: id, date: nil, name: nil, shortName: nil, weekNumber: 4, status: status,
         home: competitor("Indiana", score: home, isHome: true),
         away: competitor("Northwestern", score: away, isHome: false),
         broadcast: "FOX")
}

private func live(_ clock: String?, _ period: Int?, phase: LivePhase = .playing) -> GameStatus {
    .live(displayClock: clock, period: period, detail: nil, phase: phase, possessionTeamId: nil)
}

/// The Scores list and the game page read one game off two endpoints, and
/// the list held 1:56 while the page counted past 1:00 (2026-09-26).
@Suite struct GameProgressTests {
    @Test func clockStringsParse() {
        #expect(GameProgress.seconds(in: "1:56") == 116)
        #expect(GameProgress.seconds(in: "0:58") == 58)
        #expect(GameProgress.seconds(in: "15:00") == 900)
        #expect(GameProgress.seconds(in: "45.3") == 45.3)
        #expect(GameProgress.seconds(in: nil) == nil)
        #expect(GameProgress.seconds(in: "") == nil)
        #expect(GameProgress.seconds(in: "End") == nil)
    }

    @Test func lessOnTheClockIsFurtherAlong() {
        #expect(live("1:52", 4).isAhead(of: live("1:56", 4)))
        #expect(!live("1:56", 4).isAhead(of: live("1:52", 4)))
        #expect(!live("1:56", 4).isAhead(of: live("1:56", 4)))
    }

    @Test func aLaterPeriodBeatsAnyClock() {
        #expect(live("14:59", 3).isAhead(of: live("0:01", 2)))
        #expect(live("15:00", 3).isAhead(of: live(nil, 2, phase: .halftime)))
        #expect(live(nil, 2, phase: .halftime).isAhead(of: live("0:05", 2)))
    }

    @Test func stagesOrderPreLiveFinal() {
        #expect(live("15:00", 1).isAhead(of: .pre(detail: nil)))
        #expect(GameStatus.final(detail: "Final").isAhead(of: live("0:01", 4)))
        #expect(!live("0:01", 4).isAhead(of: .final(detail: "Final")))
    }

    @Test func unreadableCopiesAreNeverAhead() {
        #expect(!live(nil, 4).isAhead(of: live("1:56", 4)))
        #expect(!live("1:56", 4).isAhead(of: live(nil, 4)))
        #expect(!GameStatus.other(detail: "Postponed").isAhead(of: live("1:56", 4)))
        #expect(!live("1:56", 4).isAhead(of: .other(detail: "Delayed")))
    }

    @Test func aStaleBoardDoesntUndoTheGamePage() {
        let held = game("g1", status: live("0:58", 4), away: 20, home: 29)
        let staleBoard = game("g1", status: live("1:56", 4), away: 20, home: 22)
        let kept = Game.keepingProgress([staleBoard], from: [held])
        #expect(kept[0].status == live("0:58", 4))
        #expect(kept[0].home.score == 29)
        // Everything that isn't live state is still the board's.
        #expect(kept[0].home.rank == 5)
        #expect(kept[0].broadcast == "FOX")
    }

    @Test func aFresherBoardWins() {
        let held = game("g1", status: live("1:56", 4), away: 20, home: 29)
        let board = game("g1", status: live("0:40", 4), away: 27, home: 29)
        #expect(Game.keepingProgress([board], from: [held]) == [board])
    }

    @Test func aTieTakesTheBoardSoCorrectionsLand() {
        // A touchdown overturned at the same clock: the score goes down.
        let held = game("g1", status: live("1:56", 4), away: 26, home: 29)
        let board = game("g1", status: live("1:56", 4), away: 20, home: 29)
        #expect(Game.keepingProgress([board], from: [held]) == [board])
    }

    @Test func gamesNotHeldPassThrough() {
        let board = [game("g1", status: live("1:56", 4), away: 20, home: 29),
                     game("g2", status: .pre(detail: nil), away: nil, home: nil)]
        #expect(Game.keepingProgress(board, from: []) == board)
        #expect(Game.keepingProgress(board, from: [game("g9", status: .final(detail: nil), away: 1, home: 0)]) == board)
    }
}
