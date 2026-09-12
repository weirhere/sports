import SwiftUI

/// Jump to any day of the season at once — the day strip's long-range
/// counterpart (Andy, 2026-09-06, from the FotMob reference).
///
/// It supersedes the "no calendar modal" don't, which was written when the
/// strip replaced the week strip: the objection was to a *picker* standing
/// in for the axis, and the strip is still the axis. Dragging is fine for
/// the fortnight either side of today and hopeless for "the Iron Bowl in
/// November", which is the only thing this answers.
///
/// Bounded by the same `SeasonSpan` the strip is, so the sheet can't offer
/// a day the slate can't show; days outside the season render as gaps, not
/// as dead taps. Monochrome, like the rest of the chrome — the selected day
/// takes the inverted fill the strip's own selected chip wears, and today
/// (when it isn't the selection) gets the quiet elevated disc.
struct DayCalendarSheet: View {
    let days: [DaySlot]
    let selected: Date
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    /// The opening scroll runs once. A re-appear — the sheet coming back
    /// from the background — leaves the reader wherever it had scrolled to.
    @State private var hasOpenedOnSelectedMonth = false

    private var calendar: Calendar { .current }
    private var selectedId: String { DayFormat.id(for: selected) }
    private var todayId: String { DayFormat.id(for: .now) }

    /// The season's days bucketed into months, in order. Built from the
    /// strip's own `days`, so the two can never disagree about where the
    /// season starts and ends.
    private var months: [MonthGrid] {
        let grouped = Dictionary(grouping: days) { day in
            calendar.dateComponents([.year, .month], from: day.date)
        }
        return grouped.keys
            .compactMap { calendar.date(from: $0) }
            .sorted()
            .compactMap { start in
                guard let parts = grouped[calendar.dateComponents([.year, .month], from: start)]
                else { return nil }
                return MonthGrid(start: start, days: parts.sorted { $0.date < $1.date })
            }
    }

    /// The month the sheet opens on — the one the strip is already on.
    /// Nil where the selection somehow sits outside the season the sheet
    /// renders, in which case it opens at the top rather than scrolling
    /// to a section that isn't there.
    private var selectedMonthId: String? {
        let id = MonthGrid.id(of: selected, calendar: calendar)
        return months.contains { $0.id == id } ? id : nil
    }

    /// Whether today is a day this sheet could jump to at all — the same
    /// question the floating Today button asks.
    private var canJumpToToday: Bool {
        days.contains { $0.id == todayId }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.lg, pinnedViews: [.sectionHeaders]) {
                        ForEach(months) { month in
                            Section {
                                monthGrid(month)
                            } header: {
                                monthHeader(month)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.xl)
                }
                .onAppear { openOnSelectedMonth(proxy) }
            }
            .background(Color.bgRecessed)
            .safeAreaInset(edge: .top, spacing: 0) { weekdayCaptions }
            .navigationTitle("Jump to a day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.chip)
                        .foregroundStyle(.textPrimary)
                }
                if canJumpToToday {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Today") {
                            onSelect(.now)
                            dismiss()
                        }
                        .font(.chipEmphasis)
                        .foregroundStyle(.textPrimary)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    /// Opens on the month you're already in, not on the season's first
    /// (Andy, 2026-09-12 — it was opening on July).
    ///
    /// Two things were wrong with the single `onAppear` `scrollTo` this
    /// replaces, and either one alone lands the sheet at the top. The
    /// anchor id was on the `Section` rather than on a view the scroll
    /// view can position; and the call ran from `onAppear`, which is
    /// before the scroll view's first layout. The strip's own `onAppear`
    /// scroll gets away with that timing because its `HStack` isn't lazy —
    /// every chip exists to be scrolled to. This stack has realized a
    /// month or two at that point, and the months in between are what the
    /// offset is made of.
    ///
    /// So: one turn of the main actor for the first layout, then a second
    /// pass, because the first scroll is what realizes the months it
    /// travelled through and the exact landing is only knowable once they
    /// have their real heights.
    private func openOnSelectedMonth(_ proxy: ScrollViewProxy) {
        guard !hasOpenedOnSelectedMonth, let target = selectedMonthId else { return }
        hasOpenedOnSelectedMonth = true
        Task { @MainActor in
            proxy.scrollTo(target, anchor: .top)
            Task { @MainActor in proxy.scrollTo(target, anchor: .top) }
        }
    }

    /// Pinned above the grids, so the columns are always labelled however
    /// far down the season you scroll. Localized and first-weekday-aware —
    /// the grid's leading offset uses the same calendar.
    private var weekdayCaptions: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.offset) { symbol in
                Text(symbol.element)
                    .font(.rowMetaMedium)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(Color.bgRecessed)
    }

    private var orderedWeekdaySymbols: [(offset: Int, element: String)] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let rotated = Array(symbols[first...] + symbols[..<first])
        return Array(rotated.enumerated())
    }

    private func monthHeader(_ month: MonthGrid) -> some View {
        Text(month.start.formatted(.dateTime.month(.wide).year()))
            .font(.sectionHeader)
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .background(Color.bgRecessed)
            // The scroll anchor lives here, on a view the reader can
            // actually position, rather than on the `Section` around it.
            .id(month.id)
    }

    /// Seven columns, with leading blanks so the first day lands under its
    /// own weekday. A month at the season's edges is partial by design —
    /// the blanks are the days the season doesn't cover.
    private func monthGrid(_ month: MonthGrid) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                  spacing: Spacing.sm) {
            ForEach(0..<leadingBlanks(of: month), id: \.self) { _ in
                Color.clear.frame(height: 40)
            }
            ForEach(month.days) { day in
                dayCell(day)
            }
        }
        .padding(.vertical, Spacing.sm)
        .cardSurface()
    }

    private func leadingBlanks(of month: MonthGrid) -> Int {
        guard let first = month.days.first?.date else { return 0 }
        let weekday = calendar.component(.weekday, from: first)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func dayCell(_ day: DaySlot) -> some View {
        let isSelected = day.id == selectedId
        let isToday = day.id == todayId
        return Button {
            onSelect(day.date)
            dismiss()
        } label: {
            Text("\(calendar.component(.day, from: day.date))")
                .font(isSelected || isToday ? .chipEmphasis : .chip)
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.bgPrimary : Color.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(isSelected ? Color.textPrimary
                                  : (isToday ? Color.bgElevated : Color.clear))
                )
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The number alone is meaningless out of context, so the cell
        // speaks the whole date the way the strip's chips do.
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One month of the season, and only the days the season actually covers.
private struct MonthGrid: Identifiable {
    let start: Date
    let days: [DaySlot]

    var id: String { Self.id(of: start) }

    /// `"2026-09"` — the scroll target, derived the same way from a month's
    /// own start or from any day inside it.
    static func id(of date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }
}
