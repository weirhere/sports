import SwiftUI

/// The chrome row above the day strip: the `Wordmark` left, then the
/// slate's focus menu (All games · Live · Tight) and the calendar button.
/// The control is permanent (Andy, 2026-08-29): a stable home beats
/// appearing mid-Saturday, and an empty live day explains itself instead
/// of hiding the toggle. One menu chip since 2026-10-19, where the Live
/// and Tight pills stood: two pills took more of the row than Andy wanted,
/// and they were already exclusive.
///
/// The calendar joins it inside the same grouped capsule (Andy, 2026-09-06,
/// from FotMob, which puts its own calendar in exactly this slot). Two
/// pills in one glass group is what the capsule was built for — it held a
/// pair until the funnel left.
///
/// The league selector left on 2026-09-05, when the leagues stopped taking
/// turns and became accordions on the day's slate; the view-options funnel
/// went with it, and its last survivor — the Top 25 chip — followed the
/// same day. Live is the day's only scope now: "which ranked teams play"
/// is a question the Leagues tab's poll already answers.
struct ScoresHeader: View {
    let focus: SlateFocus
    let onSelectFocus: (SlateFocus) -> Void
    let onOpenCalendar: () -> Void
    var onOpenSettings: () -> Void = {}

    #if DEBUG
    @State private var showsActivityDebug = false
    #endif

    var body: some View {
        HStack(spacing: Spacing.sm) {
            wordmark
            Spacer(minLength: 0)
            // FotMob's grouped-capsule chrome (Andy, 2026-08-29): the
            // capsule carries the tap target, the pills paint their own
            // fills. Glass never stacks on glass, so the pills inside stay
            // solid. The ends get twice the top and bottom inset (Andy,
            // 2026-09-25): the capsule's round ends curve in on the pills,
            // so an even 4 read tight at the sides.
            HStack(spacing: 0) {
                SlateFocusChip(focus: focus, onSelect: onSelectFocus)
                calendarButton
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
            .glassCapsule(fallback: Color.bgElevated)
            settingsButton
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    /// The wordmark, plus — in DEBUG only — the way into the Live Activity
    /// harness. A long-press on the masthead: no chrome, no release
    /// surface, and nothing a user can reach by accident.
    @ViewBuilder
    private var wordmark: some View {
        #if DEBUG && canImport(ActivityKit)
        Wordmark()
            .onLongPressGesture(minimumDuration: 0.6) { showsActivityDebug = true }
            .sheet(isPresented: $showsActivityDebug) { LiveActivityDebugSheet() }
        #else
        Wordmark()
        #endif
    }

    /// Settings (Andy, 2026-09-24: moved here from the Teams header). Its
    /// own glass circle outside the capsule, because the capsule holds the
    /// slate's controls and this one isn't about the slate. It opens a
    /// sheet and holds no state, so it paints no fill.
    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassCircleInteractive(fallback: Color.bgElevated)
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("scores-settings-button")
    }

    /// The season at a glance, one tap from the day you're on. Never
    /// "selected" — it opens a sheet rather than holding a state — so it
    /// paints no fill, the way an unselected day chip doesn't.
    private var calendarButton: some View {
        Button(action: onOpenCalendar) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to a day")
        .accessibilityIdentifier("scores-calendar-button")
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ScoresHeader(focus: .all, onSelectFocus: { _ in }, onOpenCalendar: {})
        ScoresHeader(focus: .live, onSelectFocus: { _ in }, onOpenCalendar: {})
        ScoresHeader(focus: .tight, onSelectFocus: { _ in }, onOpenCalendar: {})
    }
    .background(Color.bgPrimary)
}
