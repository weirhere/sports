import SwiftUI

/// Horizontal day selector — the Scores screen's unit of time since both
/// leagues started sharing the page (Andy, 2026-09-05).
///
/// Past days sit left, future right, bounded by the season. A day
/// is the only unit college football and the NFL agree on: their weeks are
/// different date ranges, and college football's single "Bowls" slot
/// swallows four NFL playoff rounds whole.
struct DayStrip: View {
    let days: [DaySlot]
    let selectedId: String?
    /// Live filtering renames today (Andy, 2026-09-12) — see `namedDay`.
    var liveOnly: Bool = false
    let onSelect: (Date) -> Void

    /// The strip is only the days. The way back to today is a floating
    /// button over the slate, not a chip pinned here (Andy, 2026-09-06) —
    /// so the strip runs its full width on every day, not just today.
    var body: some View {
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
    }

    @ViewBuilder
    private func chip(for day: DaySlot) -> some View {
        let isSelected = day.id == selectedId
        Button {
            onSelect(day.date)
        } label: {
            // fixedSize: the labels are words now, not two glyphs, and a
            // chip that truncates to "Tomorr…" is worse than a wider strip.
            //
            // The selected day is ink, not a pill (Andy, 2026-09-12, from
            // FotMob): weight and darkness carry the selection, the way
            // every other emphasis in the app does. Nothing in the strip
            // is a filled surface, so the day chips are plain text at two
            // strengths — textPrimary semibold against textSecondary.
            Text(compactLabel(day.date))
                .font(isSelected ? .chipEmphasis : .chip)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        // The chip abbreviates its month and weekday; the spoken label is
        // the whole date, and the named days keep their names.
        .accessibilityLabel(spokenLabel(day.date))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id(day.id)
    }

    /// "Yesterday" / "Today" / "Tomorrow" / "Sun, Sep 27" (Andy,
    /// 2026-09-06), with today reading "Ongoing" under the Live filter
    /// (Andy, 2026-09-12).
    ///
    /// The three named days are how anyone actually refers to them, and
    /// they are the three the strip lands on most. Every other chip carries
    /// its month: the strip spans a whole season, so a bare "Sat 5" is
    /// ambiguous the moment you drag past the fortnight either side of
    /// today — and a season crosses a year boundary. Built through the
    /// localized formatter, like every other date string in the app, so
    /// the order follows the reader's calendar rather than ours.
    private func compactLabel(_ date: Date) -> String {
        if let named = Self.namedDay(date, liveOnly: liveOnly) { return named }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// Today answers to two names. Under the Live filter the day on screen
    /// isn't the whole day any more — it's whatever is being played right
    /// now — so the chip says so, FotMob's word for it.
    ///
    /// It follows the filter and not the slate: a label that flipped back
    /// to "Today" as the last game went final would be the mystery state
    /// the labelled chips exist to avoid, and the empty state ("No live
    /// games right now") is what already speaks for an empty slate.
    ///
    /// Today only. Yesterday and tomorrow keep their names under the filter
    /// — nothing is ongoing on a day that isn't this one, and a live slate
    /// there is empty by definition.
    nonisolated static func namedDay(_ date: Date,
                                     liveOnly: Bool,
                                     calendar: Calendar = .current) -> String? {
        if calendar.isDateInToday(date) { return liveOnly ? "Ongoing" : "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return nil
    }

    private func spokenLabel(_ date: Date) -> String {
        Self.namedDay(date, liveOnly: liveOnly)
            ?? date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

#Preview {
    let calendar = Calendar.current
    let days = (-4...4).compactMap { calendar.date(byAdding: .day, value: $0, to: .now) }
        .map { DaySlot($0) }
    return VStack(spacing: Spacing.lg) {
        DayStrip(days: days, selectedId: DayFormat.id(for: .now), onSelect: { _ in })
        DayStrip(days: days, selectedId: DayFormat.id(for: .now), liveOnly: true, onSelect: { _ in })
        DayStrip(days: days, selectedId: days.first?.id, onSelect: { _ in })
    }
    .background(Color.bgPrimary)
}
