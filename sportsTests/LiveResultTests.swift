import Foundation
import Testing
@testable import StatSide

// The standings dot's answer to "how's my team doing right now".

private func team(_ id: String) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 8)
}

private func game(homeScore: Int?, awayScore: Int?, live: Bool = true) -> Game {
    Game(id: "g", date: nil, name: nil, shortName: nil, weekNumber: 1,
         status: live
            ? .live(displayClock: "5:00", period: 2, detail: nil, phase: .playing, possessionTeamId: nil)
            : .final(detail: "Final"),
         home: Competitor(team: team("home"), score: homeScore, record: nil,
                          rank: nil, isHome: true, winner: nil),
         away: Competitor(team: team("away"), score: awayScore, record: nil,
                          rank: nil, isHome: false, winner: nil),
         broadcast: nil)
}

@MainActor
@Suite struct LiveResultTests {
    @Test func winningLosingAndTiedReadFromEitherSide() {
        let g = game(homeScore: 17, awayScore: 10)
        #expect(g.liveResult(for: "home") == .winning)
        #expect(g.liveResult(for: "away") == .losing)
        #expect(game(homeScore: 7, awayScore: 7).liveResult(for: "home") == .tied)
    }

    @Test func missingScoresReadAsTiedAndOutsidersGetNothing() {
        // A just-kicked game with no scores yet is a tie, not a mystery.
        #expect(game(homeScore: nil, awayScore: nil).liveResult(for: "home") == .tied)
        #expect(game(homeScore: 17, awayScore: 10).liveResult(for: "elsewhere") == nil)
        #expect(game(homeScore: 17, awayScore: 10, live: false).liveResult(for: "home") == nil)
    }
}
