import Foundation

/// One slot in a league's season calendar, parsed from ESPN's. Regular-season
/// slots carry week numbers; postseason slots carry names (Bowls, CFP).
/// Never hardcoded — Week 0 exists some years, CFP ranges shift.
///
/// The Scores screen speaks days, not weeks (2026-09-05), so nothing selects
/// a slot for display any more: these are the season coordinates a scoreboard
/// query needs, and how `CFBDClient` files a day range against a season.
nonisolated struct WeekSlot: Identifiable, Hashable, Sendable {
    let label: String
    let shortLabel: String
    let seasonType: Int   // ESPN season type: 2 regular, 3 postseason
    let value: Int        // ESPN week/slot value, used in scoreboard queries
    let startDate: Date?
    let endDate: Date?

    var id: String { "\(seasonType)-\(value)" }
    var isPostseason: Bool { seasonType == 3 }

    func contains(_ date: Date) -> Bool {
        guard let startDate, let endDate else { return false }
        return date >= startDate && date < endDate
    }
}
