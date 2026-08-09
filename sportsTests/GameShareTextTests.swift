import Foundation
import Testing
@testable import StatSide

private func competitor(_ name: String, score: Int?, rank: Int? = nil,
                        isHome: Bool, winner: Bool? = nil) -> Competitor {
    Competitor(
        team: Team(id: name, location: name, name: nil, abbreviation: nil,
                   displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil),
        score: score, record: nil, rank: rank, isHome: isHome, winner: winner
    )
}

private func game(status: GameStatus, awayScore: Int? = nil, homeScore: Int? = nil,
                  awayRank: Int? = nil, date: Date? = nil, broadcast: String? = nil) -> Game {
    Game(id: "g", date: date, name: nil, shortName: nil, weekNumber: 1, status: status,
         home: competitor("Tennessee", score: homeScore, isHome: true),
         away: competitor("Georgia", score: awayScore, rank: awayRank, isHome: false),
         broadcast: broadcast)
}

@Suite struct GameShareTextTests {
    @Test func preGameCarriesMatchupTimeAndFirstNetwork() {
        let text = game(status: .pre(detail: nil), awayRank: 3,
                        date: Date(timeIntervalSince1970: 1_787_200_200),
                        broadcast: "ESPN Unlmtd/The CW Network").shareText
        #expect(text.hasPrefix("#3 Georgia at Tennessee"))
        #expect(text.contains("on ESPN Unlmtd"))
        #expect(!text.contains("CW"))
        #expect(text.hasSuffix("— via StatSide"))
    }

    @Test func liveGameCarriesScoreAndSituation() {
        let text = game(status: .live(displayClock: "5:24", period: 3, detail: nil, possessionTeamId: nil),
                        awayScore: 24, homeScore: 17).shareText
        #expect(text.contains("Georgia 24"))
        #expect(text.contains("Tennessee 17"))
        #expect(text.contains("Q3 5:24"))
    }

    @Test func finalAndOvertimeShapes() {
        let regulation = game(status: .final(detail: "Final"), awayScore: 24, homeScore: 17).shareText
        #expect(regulation.hasPrefix("Final: Georgia 24, Tennessee 17"))

        let overtime = game(status: .final(detail: "Final/OT"), awayScore: 31, homeScore: 24).shareText
        #expect(overtime.hasPrefix("Final (OT):"))
    }

    @Test func missingDataDegradesQuietly() {
        // Nil score renders the same dash the rows use; nil broadcast and
        // date just drop their clauses.
        let live = game(status: .live(displayClock: nil, period: nil, detail: nil, possessionTeamId: nil)).shareText
        #expect(live.contains("Georgia –"))

        let pre = game(status: .pre(detail: nil)).shareText
        #expect(pre.hasPrefix("Georgia at Tennessee"))
        #expect(!pre.contains(" on "))

        let postponed = game(status: .other(detail: "Postponed")).shareText
        #expect(postponed.contains("Postponed"))
    }
}
