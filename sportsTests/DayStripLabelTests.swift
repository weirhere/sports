import Foundation
import Testing
@testable import StatSide

// The day strip's named days. Only the three named ones are asserted —
// every other chip goes through the localized formatter, so its string is
// the test machine's calendar, not ours.

private let calendar = Calendar.current

private func day(_ offset: Int) -> Date {
    calendar.date(byAdding: .day, value: offset, to: .now)!
}

@Test func todayIsTodayAtRest() {
    #expect(DayStrip.namedDay(day(0), liveOnly: false) == "Today")
}

/// Andy, 2026-09-12: the Live filter renames today, FotMob's word for it.
@Test func todayIsOngoingUnderTheLiveFilter() {
    #expect(DayStrip.namedDay(day(0), liveOnly: true) == "Ongoing")
}

/// The rename is today's alone. Nothing is ongoing on another day, and the
/// filter empties those slates by definition.
@Test func neighbouringDaysKeepTheirNamesUnderTheLiveFilter() {
    #expect(DayStrip.namedDay(day(1), liveOnly: true) == "Tomorrow")
    #expect(DayStrip.namedDay(day(-1), liveOnly: true) == "Yesterday")
}

/// An ordinary day is unnamed in both states — it falls through to the
/// formatter, which is what puts its month on the chip.
@Test func distantDaysAreUnnamedInBothStates() {
    #expect(DayStrip.namedDay(day(6), liveOnly: false) == nil)
    #expect(DayStrip.namedDay(day(6), liveOnly: true) == nil)
}
