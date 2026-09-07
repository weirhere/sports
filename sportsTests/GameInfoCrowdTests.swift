import Foundation
import Testing
@testable import StatSide

/// The Game info card's crowd numbers: what the card is willing to show,
/// and how full it says the place was.
@Suite struct GameInfoCrowdTests {
    private func summary(attendance: Int? = nil, capacity: Int? = nil,
                         venue: String? = nil, grass: Bool? = nil) -> GameSummary {
        var summary = GameSummary(
            home: nil, away: nil, status: .pre(detail: nil), scoringPlays: [], drives: [],
            teamStats: [], leaders: [], venue: venue, attendance: attendance)
        summary.venueCapacity = capacity
        summary.grassSurface = grass
        return summary
    }

    @Test func roundsTheFillPercentage() {
        #expect(GameInfoRows.fillPercent(attendance: 101_120, capacity: 102_780) == 98)
        #expect(GameInfoRows.fillPercent(attendance: 18_721, capacity: 20_099) == 93)
        // Exactly half rounds up, not down.
        #expect(GameInfoRows.fillPercent(attendance: 5, capacity: 8) == 63)
    }

    /// Standing room beats the printed capacity often enough that the
    /// meter has to survive it: the bar clamps, the number tells the truth.
    @Test func reportsOverflowCrowdsHonestly() {
        #expect(GameInfoRows.fillPercent(attendance: 111_000, capacity: 107_601) == 103)
    }

    @Test func showsTheCardForAnyVenueFactAlone() {
        #expect(GameInfoRows.hasVenueContent(summary(venue: "Ohio Stadium")))
        #expect(GameInfoRows.hasVenueContent(summary(attendance: 101_120)))
        // Capacity alone is enough now — it's the number a game that
        // hasn't published attendance still has.
        #expect(GameInfoRows.hasVenueContent(summary(capacity: 102_780)))
        #expect(GameInfoRows.hasVenueContent(summary(grass: true)))
        #expect(!GameInfoRows.hasVenueContent(summary()))
    }
}
