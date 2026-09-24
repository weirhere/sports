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

    private func team(_ name: String) -> Team {
        Team(id: name, location: name, name: nil, abbreviation: nil, displayName: nil,
             shortDisplayName: nil, logoURL: nil, conferenceId: nil)
    }

    @Test func itSpeaksBothSides() {
        let card = WinProbabilityCard(probability: .pregame(home: 44.4, away: 55.6), isFinal: false,
                                      away: team("Liberty"), home: team("Coastal Carolina"))
        #expect(card.spokenLabel == "Win probability, Liberty 56 percent, Coastal Carolina 44 percent")
    }

    // MARK: - Which number the row shows

    @Test func beforeKickoffItReadsThePredictor() {
        let reading = WinProbabilityCard.reading(.pregame(home: 44.4, away: 55.6), isFinal: false)
        #expect(abs(reading.homePercent - 44.4) < 0.001)
        #expect(reading.caption == "ESPN predictor")
    }

    @Test func liveItReadsTheLatestPlay() {
        let reading = WinProbabilityCard.reading(.series([0.68, 0.4, 0.3]), isFinal: false)
        #expect(abs(reading.homePercent - 30) < 0.001)
        #expect(reading.caption == "Live")
    }

    /// A final's latest value is just 100–0. The kickoff value is what the
    /// result, and any upset, is measured against.
    @Test func afterTheFinalItReadsTheKickoffValue() throws {
        let final = try summary("summary-final-live")
        let probability = try #require(final.winProbability)
        let reading = WinProbabilityCard.reading(probability, isFinal: true)
        #expect(abs(reading.homePercent - 68.35) < 0.001)
        #expect(reading.caption == "At kickoff")

        let card = WinProbabilityCard(probability: probability, isFinal: true,
                                      away: team("Miami"), home: team("Indiana"))
        #expect(card.spokenLabel == "Win probability at kickoff, Miami 32 percent, Indiana 68 percent")
    }
}
