import Foundation

/// One slot in the week strip, parsed from ESPN's calendar. Regular-season
/// slots carry week numbers; postseason slots carry names (Bowls, CFP).
/// Never hardcoded — Week 0 exists some years, CFP ranges shift.
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

nonisolated enum WeekLogic {
    /// The strip's default selection. ESPN's current week wins, except on
    /// Sundays: Sunday is catch-up + poll day, so we pin to the week whose
    /// Saturday just finished (the slot containing yesterday) even if ESPN
    /// has already flipped forward. Rolls over Monday morning.
    static func defaultSelection(
        in slots: [WeekSlot],
        currentWeekNumber: Int?,
        seasonType: Int?,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> WeekSlot? {
        guard !slots.isEmpty else { return nil }
        if calendar.component(.weekday, from: today) == 1,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           let slot = slots.first(where: { $0.contains(yesterday) }) {
            return slot
        }
        if let type = seasonType, let number = currentWeekNumber,
           let slot = slots.first(where: { $0.seasonType == type && $0.value == number }) {
            return slot
        }
        if let slot = slots.first(where: { $0.contains(today) }) {
            return slot
        }
        if let first = slots.first, let start = first.startDate, today < start {
            return first
        }
        return slots.last
    }
}
