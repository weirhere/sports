import Foundation
import Testing
@testable import StatSide

private func team(_ id: String) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil)
}

private func game(_ id: String, status: GameStatus,
                  homeId: String, homeWinner: Bool?,
                  awayId: String, awayWinner: Bool?) -> Game {
    Game(id: id, date: Date(timeIntervalSince1970: 0), name: nil, shortName: nil,
         weekNumber: 1, status: status,
         home: Competitor(team: team(homeId), score: nil, record: nil,
                          rank: nil, isHome: true, winner: homeWinner),
         away: Competitor(team: team(awayId), score: nil, record: nil,
                          rank: nil, isHome: false, winner: awayWinner),
         broadcast: nil)
}

private func schedule(teamId: String? = "61", games: [Game]) -> TeamSchedule {
    TeamSchedule(team: teamId.map(team), record: nil, standing: nil,
                 year: nil, games: games)
}

@Suite struct TeamScheduleDerivedRecordTests {
    @Test func countsFinalsFromTheTeamsPerspective() {
        // Two wins (one home, one away) and a loss; the pre-game and the
        // final missing its winner flags don't count.
        let derived = schedule(games: [
            game("1", status: .final(detail: nil),
                 homeId: "61", homeWinner: true, awayId: "2", awayWinner: false),
            game("2", status: .final(detail: nil),
                 homeId: "3", homeWinner: false, awayId: "61", awayWinner: true),
            game("3", status: .final(detail: nil),
                 homeId: "61", homeWinner: false, awayId: "4", awayWinner: true),
            game("4", status: .final(detail: nil),
                 homeId: "61", homeWinner: nil, awayId: "5", awayWinner: nil),
            game("5", status: .pre(detail: nil),
                 homeId: "61", homeWinner: nil, awayId: "6", awayWinner: nil),
        ]).derivedRecord
        #expect(derived == "2-1")
    }

    @Test func nilWithoutAnyFinals() {
        #expect(schedule(games: []).derivedRecord == nil)
        #expect(schedule(games: [
            game("1", status: .pre(detail: nil),
                 homeId: "61", homeWinner: nil, awayId: "2", awayWinner: nil)
        ]).derivedRecord == nil)
    }

    @Test func nilWhenTheTeamsIdentityIsUnknown() {
        // Without a team id, wins can't be attributed to a side.
        #expect(schedule(teamId: nil, games: [
            game("1", status: .final(detail: nil),
                 homeId: "61", homeWinner: true, awayId: "2", awayWinner: false)
        ]).derivedRecord == nil)
    }
}
