import Foundation
import Testing
@testable import StatSide

// The win-probability card's data (Coard Miller, 2026-09-24): ESPN's
// matchup predictor before kickoff, the per-play line after it, and
// nothing for hockey, whose payload has neither.

private final class WinProbabilityFixtureToken {}

private func summary(_ name: String) throws -> GameSummary {
    let url = try #require(
        Bundle(for: WinProbabilityFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json")
    let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: Data(contentsOf: url))
    return ESPNMapper.gameSummary(from: dto)
}

@Suite struct WinProbabilityTests {
    @Test func beforeKickoffItIsThePredictor() throws {
        // Liberty @ Coastal Carolina, captured 2026-09-24 before kickoff.
        let probability = try #require(try summary("cfb-summary-pregame").winProbability)
        #expect(probability == .pregame(home: 44.4, away: 55.6))
        #expect(abs(probability.homePercent - 44.4) < 0.001)
    }

    @Test func footballAndBasketballCarryTheLine() throws {
        guard case .series(let football) = try summary("summary-final-live").winProbability else {
            Issue.record("expected a series"); return
        }
        #expect(football.count == 175)
        #expect(football.last == 1.0)

        guard case .series(let basketball) = try summary("nba-summary").winProbability else {
            Issue.record("expected a series"); return
        }
        #expect(basketball.count == 490)
    }

    @Test func hockeyHasNoCard() throws {
        #expect(try summary("nhl-summary").winProbability == nil)
    }

    @Test func theLineWinsOnceItHasTwoPoints() {
        #expect(WinProbability(predictor: (60, 40), series: [0.6]) == .pregame(home: 60, away: 40))
        #expect(WinProbability(predictor: (60, 40), series: [0.6, 0.7]) == .series([0.6, 0.7]))
    }

    @Test func outOfRangePointsAreClamped() {
        #expect(WinProbability(predictor: nil, series: [-0.2, 1.4]) == .series([0, 1]))
    }

    @Test func aBrokenPredictorIsNoCard() {
        #expect(WinProbability(predictor: (nil, 40), series: []) == nil)
        #expect(WinProbability(predictor: (0, 0), series: []) == nil)
    }

    @Test func itSpeaksBothSides() {
        func team(_ name: String) -> Team {
            Team(id: name, location: name, name: nil, abbreviation: nil, displayName: nil,
                 shortDisplayName: nil, logoURL: nil, conferenceId: nil)
        }
        let card = WinProbabilityCard(probability: .pregame(home: 44.4, away: 55.6),
                                      away: team("Liberty"), home: team("Coastal Carolina"))
        #expect(card.spokenLabel == "Win probability, Liberty 56 percent, Coastal Carolina 44 percent")
    }
}
