import SwiftUI

/// Horizontal day selector — the Scores screen's unit of time since both
/// leagues started sharing the page (Andy, 2026-09-05).
///
/// Past days sit left, future right, bounded by the season. A day
/// is the only unit college football and the NFL agree on: their weeks are
/// different date ranges, and college football's single "Bowls" slot
/// swallows four NFL playoff rounds whole.
struct DayStrip: View, Equatable {
    let days: [DaySlot]
    let selectedId: String?
    /// Live filtering renames today (Andy, 2026-09-12) — see `namedDay`.
    var liveOnly: Bool = false
    /// Today's `DayFormat.id`, passed in rather than read from the clock so
    /// the strip's equality notices midnight — the named chips move then.
    var todayId: String = DayFormat.id(for: .now)
    let onSelect: (Date) -> Void

    /// Everything but `onSelect`. The strip is eager — a season of chips —
    /// and a closure prop never compares equal, so without this every body
    /// pass of the Scores screen re-diffed all of them, including each
    /// frame of a day drag (2026-09-24). The closure only ever routes to
    /// `select(day:)`, so ignoring it can't strand a stale action.
    static func == (lhs: DayStrip, rhs: DayStrip) -> Bool {
        lhs.selectedId == rhs.selectedId
            && lhs.liveOnly == rhs.liveOnly
            && lhs.todayId == rhs.todayId
            && lhs.days == rhs.days
    }

    /// The strip is only the days. The way back to today is a floating
    /// button over the slate, not a chip pinned here (Andy, 2026-09-06) —
    /// so the strip runs its full width on every day, not just today.
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                // A plain `HStack`, deliberately, after a `LazyHStack`
                // was tried and reverted the same day (2026-09-21).
                //
                // The strip is a season — `days()` walks `SeasonSpan` from
                // July to June — so building ~365 chips to show eight looks
                // like the obvious thing to make lazy. It is not worth it,
                // and the attempt broke two things at once. A `LazyHStack`
                // does not size to its children the way an `HStack` does,
                // so the strip stretched to whatever height the ScrollView
                // proposed and left the chips floating in a band. And the
                // reveal stopped landing: `scrollTo` on `onAppear` ran
                // before the target chip existed, so the strip opened on
                // July 1 instead of the selected day — with today's chip
                // hundreds of positions away, which is the one thing this
                // control cannot do.
                //
                // The cost it was buying is small: a `DaySlot` is one
                // `Date`, and the strip moves no network at all — the fetch
                // is in `select(day:)`, per day landed on rather than per
                // chip. Eager construction of 365 tiny text views is the
                // cheaper mistake.
                let names = namedDays
                HStack(spacing: Spacing.xs) {
                    ForEach(days) { day in
                        chip(for: day, name: names[day.id])
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            }
            // Today's chip becomes "Ongoing" inside the Live toggle's
            // `withAnimation`, and inherited it — so the word grew and the
            // strip shuffled (Andy, 2026-09-21). It is a relabel, not a
            // move: it snaps.
            .animation(nil, value: liveOnly)
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
            // The label changes width without the day changing: today
            // becomes "Ongoing" under the Live filter, which is longer than
            // "Today". The chip stayed where it was and drifted off centre,
            // because the only thing re-centring the strip was a change of
            // *day* (Andy, 2026-09-21).
            //
            // Unanimated on purpose. Nothing moved — the same chip is the
            // same chip, a word longer — so sliding the strip would suggest
            // a navigation that did not happen. It snaps.
            .onChange(of: liveOnly) { _, _ in
                if let selectedId {
                    proxy.scrollTo(selectedId, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for day: DaySlot, name: String?) -> some View {
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
            Text(name ?? day.shortLabel)
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
        .accessibilityLabel(name ?? day.spokenLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id(day.id)
    }

    /// "Yesterday" / "Today" / "Tomorrow" / "Sun, Sep 27" (Andy,
    /// 2026-09-06), with today reading "Ongoing" under the Live filter
    /// (Andy, 2026-09-12).
    ///
    /// The three named days are how anyone actually refers to them, and
    /// they are the three the strip lands on most. Every other chip carries
    /// its month (`DaySlot.shortLabel`): the strip spans a whole season, so
    /// a bare "Sat 5" is ambiguous the moment you drag past the fortnight
    /// either side of today — and a season crosses a year boundary. Built
    /// through the localized formatter, like every other date string in the
    /// app, so the order follows the reader's calendar rather than ours.
    ///
    /// The names are keyed by day id and worked out once per body — three
    /// dates — rather than asking the calendar about every chip in the
    /// season.
    private var namedDays: [String: String] {
        let calendar = Calendar.current
        var names: [String: String] = [:]
        for offset in -1...1 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: .now),
                  let name = Self.namedDay(date, liveOnly: liveOnly, calendar: calendar)
            else { continue }
            names[DayFormat.id(for: date, calendar: calendar)] = name
        }
        return names
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
