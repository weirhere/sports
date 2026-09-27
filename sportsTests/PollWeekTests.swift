import Foundation
import Testing
@testable import StatSide

/// The Top 25's week chip: which weeks a season's poll index names, what
/// the menu calls them, and the order they sort in.
struct PollWeekTests {
    private let base = "http://sports.core.api.espn.com/v2/sports/football/leagues/college-football"

    @Test func parsesTypeAndWeekOutOfARef() {
        let week = PollWeek(ref: "\(base)/seasons/2025/types/2/weeks/7/rankings/1?lang=en&region=us")
        #expect(week == PollWeek(seasonType: 2, number: 7))
    }

    @Test func rejectsARefWithNoWeek() {
        #expect(PollWeek(ref: "\(base)/seasons/2025/rankings/1?lang=en") == nil)
    }

    @Test func labelsPreseasonWeeksAndFinal() {
        #expect(PollWeek(seasonType: 1, number: 1).label == "Preseason")
        #expect(PollWeek(seasonType: 2, number: 12).label == "Week 12")
        #expect(PollWeek(seasonType: 3, number: 1).label == "Final")
    }

    /// Preseason, then the weeks numerically (10 after 9, not after 1),
    /// then the final vote — so the latest week is always `.last`.
    @Test func sortsChronologically() {
        let shuffled = [PollWeek(seasonType: 3, number: 1), PollWeek(seasonType: 2, number: 10),
                        PollWeek(seasonType: 1, number: 1), PollWeek(seasonType: 2, number: 9)]
        #expect(shuffled.sorted().map(\.label) == ["Preseason", "Week 9", "Week 10", "Final"])
    }
}
