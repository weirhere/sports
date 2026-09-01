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

private func game(status: GameStatus) -> Game {
    Game(id: "g", date: nil, name: nil, shortName: nil, weekNumber: 1, status: status,
         home: competitor("Tennessee", score: 17, isHome: true),
         away: competitor("Georgia", score: 24, isHome: false),
         broadcast: nil)
}

private func summary(status: GameStatus) -> GameSummary {
    GameSummary(home: nil, away: nil, status: status, scoringPlays: [],
                drives: [], teamStats: [], leaders: [], venue: nil, attendance: nil)
}

private let liveQ3 = GameStatus.live(displayClock: "5:24", period: 3, detail: nil,
                                     phase: .playing, possessionTeamId: nil)

/// The merged-status rule every header surface (detail header, share card,
/// poll gate) renders from. The load-bearing case: a flaky pre-game
/// summary against a live scoreboard snapshot must NOT win — honoring it
/// froze the detail screen mid-drive (pre header, poll loop cancelled
/// with nothing left to refetch the summary).
@Suite struct GameHeaderStateTests {
    @Test func summaryStatusWinsWhenPresent() {
        let merged = GameHeaderState.status(game(status: liveQ3),
                                            summary(status: .final(detail: "Final")))
        guard case .final = merged else {
            Issue.record("summary's final should win over the live snapshot")
            return
        }
    }

    @Test func preSummaryNeverDemotesALiveSnapshot() {
        let merged = GameHeaderState.status(game(status: liveQ3),
                                            summary(status: .pre(detail: nil)))
        guard case .live = merged else {
            Issue.record("kickoff doesn't un-happen: the live snapshot should win")
            return
        }
        #expect(GameHeaderState.isLive(game(status: liveQ3),
                                       summary(status: .pre(detail: nil))))
        #expect(GameHeaderState.showsScores(game(status: liveQ3),
                                            summary(status: .pre(detail: nil))))
    }

    @Test func preSummaryOverAPreSnapshotStaysPre() {
        let merged = GameHeaderState.status(game(status: .pre(detail: nil)),
                                            summary(status: .pre(detail: nil)))
        guard case .pre = merged else {
            Issue.record("two pre statuses should stay pre")
            return
        }
    }

    @Test func nilSummaryFallsBackToTheSnapshot() {
        #expect(GameHeaderState.isLive(game(status: liveQ3), nil))
        #expect(!GameHeaderState.isLive(game(status: .pre(detail: nil)), nil))
    }

    @Test func liveSummaryOverAPreSnapshotWins() {
        // The mirror case is legitimate: the summary learned about kickoff
        // before the scoreboard's pushed snapshot did.
        #expect(GameHeaderState.isLive(game(status: .pre(detail: nil)),
                                       summary(status: liveQ3)))
    }

    /// The detail screen's poll loop is gated on `isLive`, so this pair is
    /// the self-stop the 2026-08-29 live pass could never observe (a ghost
    /// activation ended every hold before a whistle did): once the summary
    /// comes back final, the gate flips false and `.task(id:)` cancels the
    /// loop. Scores stay on screen — a final has everything left to show.
    @Test func finalSummaryStopsTheDetailPoll() {
        let live = game(status: liveQ3)
        let ended = summary(status: .final(detail: "Final"))
        #expect(!GameHeaderState.isLive(live, ended))
        #expect(GameHeaderState.showsScores(live, ended))
        #expect(GameHeaderState.statusLine(live, ended) == "Final")
    }

    @Test func postponedSummaryStopsTheDetailPoll() {
        let live = game(status: liveQ3)
        let called = summary(status: .other(detail: "Postponed"))
        #expect(!GameHeaderState.isLive(live, called))
        #expect(GameHeaderState.statusLine(live, called) == "Postponed")
    }

    /// The mirror, deliberately NOT a self-stop: a pushed snapshot that has
    /// gone final while the summary still says live keeps polling. The
    /// summary is the fresher surface here, and the next tick retires the
    /// loop on its own — stopping early on the stale half would strand the
    /// header on a score the summary hasn't caught up to.
    @Test func finalSnapshotUnderALiveSummaryKeepsPolling() {
        #expect(GameHeaderState.isLive(game(status: .final(detail: "Final")),
                                       summary(status: liveQ3)))
    }
}
