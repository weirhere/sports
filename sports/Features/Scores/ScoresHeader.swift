import SwiftUI

/// The chrome row above the day strip: StatSide wordmark left, then the
/// Live toggle and the calendar button. The Live chip is permanent (Andy,
/// 2026-08-29): a stable home beats appearing mid-Saturday, and an empty
/// live day explains itself instead of hiding the toggle.
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
/// is a question the Tables tab's poll already answers.
struct ScoresHeader: View {
    let liveOnly: Bool
    let onToggleLive: () -> Void
    let onOpenCalendar: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            wordmark
            Spacer(minLength: 0)
            // FotMob's grouped-capsule chrome (Andy, 2026-08-29): the
            // capsule carries the tap target, the pills paint their own
            // fills. Glass never stacks on glass, so the pills inside stay
            // solid.
            HStack(spacing: 0) {
                LiveFilterChip(liveOnly: liveOnly, onToggle: onToggleLive)
                calendarButton
            }
            .padding(4)
            .glassCapsule(fallback: Color.bgElevated)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
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

    private var wordmark: some View {
        HStack(spacing: Spacing.xs + 2) {
            Image(systemName: "football.fill")
                .font(.system(size: 15, weight: .semibold))
            Text("StatSide")
                .font(.system(size: 17, weight: .heavy))
                .lineLimit(1)
        }
        .foregroundStyle(.textPrimary)
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ScoresHeader(liveOnly: false, onToggleLive: {}, onOpenCalendar: {})
        ScoresHeader(liveOnly: true, onToggleLive: {}, onOpenCalendar: {})
    }
    .background(Color.bgPrimary)
}
