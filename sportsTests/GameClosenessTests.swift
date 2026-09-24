import Foundation
import Testing
@testable import StatSide

// The Tight filter's rule (Coard Miller, 2026-09-24): live, and either late
// and within one score, or with the underdog leading in the second half.

private func game(_ league: League, period: Int?, home: Int?, away: Int?,
                  phase: LivePhase = .playing, favoriteIsHome: Bool? = nil,
                  status: GameStatus? = nil) -> Game {
    func team(_ id: String) -> Team {
        Team(id: id, location: "Team \(id)", name: nil, abbreviation: "T\(id)",
             displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil,
             league: league)
    }
    let line = favoriteIsHome.flatMap { GameLine(details: "X -3.5", overUnder: nil, favoriteIsHome: $0) }
    return Game(id: "g", date: nil, name: nil, shortName: nil, weekNumber: nil,
                status: status ?? .live(displayClock: "5:00", period: period, detail: nil,
                                        phase: phase, possessionTeamId: nil),
                home: Competitor(team: team("1"), score: home, record: nil, rank: nil, isHome: true, winner: nil),
                away: Competitor(team: team("2"), score: away, record: nil, rank: nil, isHome: false, winner: nil),
                broadcast: nil, line: line)
}

@Suite struct GameClosenessTests {
    // MARK: - Late and within one score

    @Test func footballIsOneScoreInTheFourth() {
        #expect(GameCloseness.isTight(game(.nfl, period: 4, home: 21, away: 13)))
        #expect(!GameCloseness.isTight(game(.nfl, period: 4, home: 22, away: 13)))
        #expect(!GameCloseness.isTight(game(.collegeFootball, period: 3, home: 14, away: 14)))
        #expect(GameCloseness.isTight(game(.collegeFootball, period: 5, home: 31, away: 31)))
    }

    @Test func basketballIsTwoPossessionsInTheFourth() {
        #expect(GameCloseness.isTight(game(.nba, period: 4, home: 100, away: 94)))
        #expect(!GameCloseness.isTight(game(.nba, period: 4, home: 101, away: 94)))
    }

    @Test func hockeyIsOneGoalInTheThird() {
        #expect(GameCloseness.isTight(game(.nhl, period: 3, home: 2, away: 1)))
        #expect(!GameCloseness.isTight(game(.nhl, period: 3, home: 3, away: 1)))
        #expect(!GameCloseness.isTight(game(.nhl, period: 2, home: 1, away: 1)))
        #expect(GameCloseness.isTight(game(.nhl, period: 4, home: 2, away: 2)))
    }

    // MARK: - The underdog leading

    @Test func anUnderdogAheadInTheSecondHalfCounts() {
        // Home favored, away up 17 in the 3rd: not close, but an upset brewing.
        #expect(GameCloseness.isTight(game(.collegeFootball, period: 3, home: 7, away: 24,
                                           favoriteIsHome: true)))
        // The favorite ahead is just the expected game.
        #expect(!GameCloseness.isTight(game(.collegeFootball, period: 3, home: 24, away: 7,
                                            favoriteIsHome: true)))
    }

    @Test func halftimeIsTheSecondHalfsDoorstep() {
        #expect(GameCloseness.isTight(game(.nfl, period: 2, home: 3, away: 17,
                                           phase: .halftime, favoriteIsHome: true)))
        #expect(!GameCloseness.isTight(game(.nfl, period: 2, home: 3, away: 17,
                                            favoriteIsHome: true)))
    }

    @Test func hockeysSecondHalfIsItsSecondPeriod() {
        #expect(GameCloseness.isTight(game(.nhl, period: 2, home: 0, away: 3, favoriteIsHome: true)))
    }

    @Test func noLineMeansOnlyTheLateRuleSpeaks() {
        #expect(!GameCloseness.isTight(game(.collegeFootball, period: 3, home: 7, away: 24)))
    }

    // MARK: - Only live games

    @Test func preGameAndFinalsNeverQualify() {
        #expect(!GameCloseness.isTight(game(.nfl, period: nil, home: nil, away: nil,
                                            status: .pre(detail: nil))))
        #expect(!GameCloseness.isTight(game(.nfl, period: 4, home: 20, away: 17,
                                            status: .final(detail: "Final"))))
    }
}

@Suite struct TightFilterStateTests {
    private func store() -> UIStateStore {
        let suite = "tight-\(UUID().uuidString)"
        return UIStateStore(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func liveAndTightAreExclusive() {
        let state = store()
        state.liveOnly = true
        state.tightOnly = true
        #expect(state.tightOnly && !state.liveOnly)
        state.liveOnly = true
        #expect(state.liveOnly && !state.tightOnly)
    }

    @Test func eitherRenamesTodayOngoing() {
        let state = store()
        #expect(!state.narrowsToNow)
        state.tightOnly = true
        #expect(state.narrowsToNow)
    }
}

@Suite struct CarriedLineTests {
    private func game(_ id: String, line: GameLine?) -> Game {
        let team = Team(id: "1", location: "A", name: nil, abbreviation: "A",
                        displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil)
        return Game(id: id, date: nil, name: nil, shortName: nil, weekNumber: nil,
                    status: .pre(detail: nil),
                    home: Competitor(team: team, score: nil, record: nil, rank: nil, isHome: true, winner: nil),
                    away: Competitor(team: team, score: nil, record: nil, rank: nil, isHome: false, winner: nil),
                    broadcast: nil, line: line)
    }

    @Test func aLineOutlivesThePayloadThatDropsIt() {
        let line = GameLine(details: "LIB -2.5", overUnder: 50.5, favoriteIsHome: false)
        let kept = ScoreboardStore.keepingLines([game("1", line: nil), game("2", line: nil)],
                                                from: [game("1", line: line)])
        #expect(kept[0].line == line)
        #expect(kept[1].line == nil)
    }

    @Test func aFreshLineWins() {
        let old = GameLine(details: "LIB -2.5", overUnder: 50.5)
        let new = GameLine(details: "LIB -3", overUnder: 51)
        let kept = ScoreboardStore.keepingLines([game("1", line: new)], from: [game("1", line: old)])
        #expect(kept[0].line == new)
    }
}
