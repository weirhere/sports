import SwiftUI

/// Horizontal day selector — the Scores screen's unit of time since both
/// leagues started sharing the page (Andy, 2026-09-05).
///
/// Past days sit left, future right, bounded by the selected season. A day
/// is the only unit college football and the NFL agree on: their weeks are
/// different date ranges, and college football's single "Bowls" slot
/// swallows four NFL playoff rounds whole.
struct DayStrip: View {
    let days: [DaySlot]
    let selectedId: String?
    /// Shown as a leading jump-home chip whenever the strip has wandered
    /// off it. A season is ~200 chips wide, so finding today again by
    /// dragging is not a plan.
    let today: Date
    let onSelect: (Date) -> Void

    private var todayId: String { DayFormat.id(for: today) }
    private var showsTodayJump: Bool {
        selectedId != todayId && days.contains { $0.id == todayId }
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(days) { day in
                            chip(for: day)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                }
                .onAppear {
                    if let selectedId {
                        proxy.scrollTo(selectedId, anchor: .center)
                    }
                }
                .onChange(of: selectedId) { _, newValue in
                    if let newValue {
                        withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                    }
                }
            }
            if showsTodayJump {
                todayJump
            }
        }
    }

    /// Pinned to the strip's trailing edge rather than riding inside it: a
    /// season is ~200 chips wide, and a jump-home button that scrolls away
    /// with the content is a jump-home button you can never find.
    ///
    /// Never "selected" — it is a shortcut back, not a date of its own —
    /// and it disappears the moment it would be redundant, which is what
    /// gives the strip its full width on the day that matters most.
    private var todayJump: some View {
        Button {
            onSelect(today)
        } label: {
            Text("Today")
                .font(.chip)
                .fixedSize()
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
                .glassCapsule(fallback: Color.bgElevated)
        }
        .buttonStyle(.plain)
        .padding(.trailing, Spacing.md)
        .accessibilityLabel("Jump to today")
        .accessibilityIdentifier("day-strip-today")
    }

    @ViewBuilder
    private func chip(for day: DaySlot) -> some View {
        let isSelected = day.id == selectedId
        Button {
            onSelect(day.date)
        } label: {
            let label = Text(compactLabel(day.date))
                .font(.chip)
                .foregroundStyle(isSelected ? Color.bgPrimary : Color.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
            // The selected chip is the strip's one piece of floating
            // chrome — ink-tinted glass on iOS 26, the solid capsule on
            // the 18.0 floor. Unselected chips stay bare text.
            if isSelected {
                label.glassCapsuleInteractive(tint: Color.textPrimary,
                                              fallback: Color.textPrimary)
            } else {
                label
            }
        }
        .buttonStyle(.plain)
        // The chip is two glyphs wide; the spoken label is the whole date,
        // and "Today" and "Tomorrow" keep their meaning rather than being
        // read as a bare weekday.
        .accessibilityLabel(spokenLabel(day.date))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id(day.id)
    }

    /// "Today" / "Sat 6" — the strip is contiguous, so the day number needs
    /// no month beside it.
    private func compactLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        let day = calendar.component(.day, from: date)
        return "\(date.formatted(.dateTime.weekday(.abbreviated))) \(day)"
    }

    private func spokenLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

#Preview {
    let calendar = Calendar.current
    let days = (-4...4).compactMap { calendar.date(byAdding: .day, value: $0, to: .now) }
        .map { DaySlot($0) }
    return VStack(spacing: Spacing.lg) {
        DayStrip(days: days, selectedId: DayFormat.id(for: .now),
                 today: .now, onSelect: { _ in })
        DayStrip(days: days,
                 selectedId: days.first?.id,
                 today: .now, onSelect: { _ in })
    }
    .background(Color.bgPrimary)
}
