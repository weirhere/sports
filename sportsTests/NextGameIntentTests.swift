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

private func game(status: GameStatus, away: Int?, home: Int?) -> Game {
    Game(id: "g", date: nil, name: nil, shortName: nil, weekNumber: 1, status: status,
         home: competitor("Tennessee", score: home, isHome: true),
         away: competitor("Georgia", score: away, isHome: false),
         broadcast: nil)
}

private func live(period: Int?, clock: String?, phase: LivePhase = .playing) -> GameStatus {
    .live(displayClock: clock, period: period, detail: nil, phase: phase, possessionTeamId: nil)
}

/// Siri speaks these, so they get held to the app's own honesty rules: no
/// invented score, and a parked clock is a break rather than a quarter
/// running out (decision log, 2026-08-31).
@Suite struct NextGameIntentTests {
    @Test func liveLineSpeaksTheScoreAndTheClock() {
        let line = NextGameIntent.liveLine(for: game(status: live(period: 3, clock: "5:24"),
                                                     away: 24, home: 17))
        #expect(line == "Live now: Georgia 24, Tennessee 17, in the 3rd quarter, 5:24 left.")
    }

    /// The bug this suite was written for: the schedule payload carries no
    /// live score, and the old line defaulted a missing one to "0" — so
    /// Siri announced a confident 0–0 mid-drive.
    @Test func aMissingScoreIsNeverSpokenAsZero() {
        let line = NextGameIntent.liveLine(for: game(status: live(period: 2, clock: "1:12"),
                                                     away: nil, home: nil))
        #expect(!line.contains("0"))
        #expect(line == "Georgia and Tennessee are playing right now, in the 2nd quarter, 1:12 left.")
    }

    @Test func halftimeIsABreakNotAQuarter() {
        let line = NextGameIntent.liveLine(for: game(status: live(period: 2, clock: "0:00",
                                                                 phase: .halftime),
                                                     away: 14, home: 10))
        #expect(line == "Live now: Georgia 14, Tennessee 10, at halftime.")
    }

    @Test func endOfPeriodSaysSo() {
        let line = NextGameIntent.liveLine(for: game(status: live(period: 1, clock: "0:00",
                                                                 phase: .endOfPeriod),
                                                     away: 7, home: 0))
        #expect(line == "Live now: Georgia 7, Tennessee 0, at the end of the 1st quarter.")
    }

    @Test func overtimeIsNamedNotNumbered() {
        let line = NextGameIntent.liveLine(for: game(status: live(period: 5, clock: "0:48"),
                                                     away: 31, home: 31))
        #expect(line == "Live now: Georgia 31, Tennessee 31, in overtime, 0:48 left.")
    }

    @Test func aClocklessLiveGameStillAnswers() {
        let line = NextGameIntent.liveLine(for: game(status: live(period: nil, clock: nil),
                                                     away: 3, home: 0))
        #expect(line == "Live now: Georgia 3, Tennessee 0.")
    }
}
