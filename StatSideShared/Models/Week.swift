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
    /// the league's catch-up days, when we pin to the week that just
    /// finished (the slot containing the most recent game day) even if
    /// ESPN has already flipped forward.
    ///
    /// College football's slate is Saturday, so Sunday is catch-up day —
    /// it's also when the new poll drops in place — and the strip rolls
    /// over Monday morning. The NFL's week runs Thursday → Monday, so
    /// Monday night football is still *this* week and Tuesday is the dead
    /// day; both pin back, and the strip rolls over Wednesday morning.
    static func defaultSelection(
        in slots: [WeekSlot],
        currentWeekNumber: Int?,
        seasonType: Int?,
        league: League = .collegeFootball,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> WeekSlot? {
        guard !slots.isEmpty else { return nil }
        if league.completedWeekWeekdays.contains(calendar.component(.weekday, from: today)),
           let yesterday = lastGameDay(before: today, in: league, calendar: calendar) {
            // The Bowls and CFP slots overlap for the whole playoff (Dec 18
            // → Jan 28 both sit inside Bowls' range), so several slots can
            // contain yesterday — the NFL's Wild Card and Divisional slots
            // overlap the same way. ESPN's current slot breaks the tie when
            // it qualifies; first-containing keeps the September behavior,
            // where ESPN's flipped-forward week never contains yesterday.
            let containing = slots.filter { $0.contains(yesterday) }
            if let type = seasonType, let number = currentWeekNumber,
               let current = containing.first(where: { $0.seasonType == type && $0.value == number }) {
                return current
            }
            if let slot = containing.first {
                return slot
            }
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

    /// The most recent day that belongs to the week just finished. College
    /// football looks back one day from Sunday to Saturday. The NFL looks
    /// back to Monday, which means Tuesday looks back two days — Monday
    /// night's game is the week's last.
    private static func lastGameDay(
        before today: Date, in league: League, calendar: Calendar
    ) -> Date? {
        let weekday = calendar.component(.weekday, from: today)
        let step = league.completedWeekWeekdays.sorted().first.map { weekday - $0 + 1 } ?? 1
        return calendar.date(byAdding: .day, value: -max(step, 1), to: today)
    }
}
