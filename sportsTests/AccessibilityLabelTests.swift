import Foundation
import Testing
@testable import sports

// The VoiceOver sentences the rows speak. Dates are omitted from fixtures
// where possible so assertions don't depend on the test machine's locale.

private func team(_ id: String, _ location: String) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 8)
}

private let georgia = team("61", "Georgia")
private let tennessee = team("2633", "Tennessee")

private func game(status: GameStatus,
                  homeScore: Int? = nil, awayScore: Int? = nil,
                  homeRecord: String? = nil, awayRecord: String? = nil,
                  homeRank: Int? = nil, awayRank: Int? = nil,
                  homeWinner: Bool? = nil, awayWinner: Bool? = nil,
                  broadcast: String? = nil) -> Game {
    Game(id: "1", date: nil, name: nil, shortName: nil, weekNumber: 5,
         status: status,
         home: Competitor(team: tennessee, score: homeScore, record: homeRecord,
                          rank: homeRank, isHome: true, winner: homeWinner),
         away: Competitor(team: georgia, score: awayScore, record: awayRecord,
                          rank: awayRank, isHome: false, winner: awayWinner),
         broadcast: broadcast)
}

@MainActor
@Suite struct GameRowAccessibilityTests {
    @Test func liveRowSpeaksScoresQuarterClockAndPossession() {
        let row = GameRow(game: game(
            status: .live(displayClock: "5:24", period: 3, detail: nil, possessionTeamId: "61"),
            homeScore: 17, awayScore: 24))
        #expect(row.accessibilitySummary ==
                "Georgia 24, Tennessee 17, 3rd quarter, 5:24 left, Georgia has the ball")
    }

    @Test func liveRowSpeaksRanksAndOvertime() {
        let row = GameRow(game: game(
            status: .live(displayClock: "0:48", period: 5, detail: nil, possessionTeamId: nil),
            homeScore: 27, awayScore: 27, homeRank: 12, awayRank: 3))
        #expect(row.accessibilitySummary ==
                "number 3 Georgia 27, number 12 Tennessee 27, overtime, 0:48 left")
    }

    @Test func preRowSpeaksRecordsAndNetwork() {
        let row = GameRow(game: game(
            status: .pre(detail: nil),
            homeRecord: "4-1", awayRecord: "5-0", broadcast: "ESPN"))
        #expect(row.accessibilitySummary ==
                "Georgia 5 and 0 at Tennessee 4 and 1, on ESPN")
    }

    @Test func finalRowSpeaksOvertimeWhenDetailHasOT() {
        let row = GameRow(game: game(
            status: .final(detail: "Final/OT"),
            homeScore: 24, awayScore: 27, homeWinner: false, awayWinner: true))
        #expect(row.accessibilitySummary == "Georgia 27, Tennessee 24, final, overtime")
    }
}

@MainActor
@Suite struct RankRowAccessibilityTests {
    private func ranked(current: Int, previous: Int?, votes: Int? = nil,
                        record: String? = nil) -> RankedTeam {
        RankedTeam(team: georgia, current: current, previous: previous,
                   points: nil, firstPlaceVotes: votes, record: record)
    }

    @Test func movementUpWithVotesAndRecord() {
        let row = RankRow(ranked: ranked(current: 3, previous: 5, votes: 12, record: "5-0"))
        #expect(row.accessibilitySummary ==
                "Number 3, Georgia, 12 first-place votes, 5 and 0, up 2")
    }

    @Test func newlyRankedWhenNoPrevious() {
        let row = RankRow(ranked: ranked(current: 25, previous: nil))
        #expect(row.accessibilitySummary == "Number 25, Georgia, newly ranked")
    }

    @Test func movementDown() {
        let row = RankRow(ranked: ranked(current: 8, previous: 4))
        #expect(row.accessibilitySummary == "Number 8, Georgia, down 4")
    }
}

@MainActor
@Suite struct ScheduleRowAccessibilityTests {
    @Test func finalSpeaksOutcomeFromTeamPerspective() {
        // Georgia's page, Georgia won on the road: "at Tennessee, won 27 to 24".
        let row = ScheduleRow(game: game(
            status: .final(detail: "Final"),
            homeScore: 24, awayScore: 27, homeWinner: false, awayWinner: true),
            teamId: "61")
        #expect(row.accessibilitySummary == "at Tennessee, won 27 to 24")
    }

    @Test func finalSpeaksLossForHomeTeam() {
        let row = ScheduleRow(game: game(
            status: .final(detail: "Final"),
            homeScore: 24, awayScore: 27, homeWinner: false, awayWinner: true),
            teamId: "2633")
        #expect(row.accessibilitySummary == "versus Georgia, lost 24 to 27")
    }
}
