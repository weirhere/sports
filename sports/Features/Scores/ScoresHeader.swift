import SwiftUI

/// The chrome row above the day strip: StatSide wordmark left, the Live
/// toggle right. The chip is permanent (Andy, 2026-08-29): a stable home
/// beats appearing mid-Saturday, and an empty live day explains itself
/// instead of hiding the toggle.
///
/// The league selector left on 2026-09-05, when the leagues stopped taking
/// turns and became accordions on the day's slate; the view-options funnel
/// went with it, and its last survivor — the Top 25 chip — followed the
/// same day. Live is the day's only scope now: "which ranked teams play"
/// is a question the Tables tab's poll already answers.
struct ScoresHeader: View {
    let liveOnly: Bool
    let onToggleLive: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            wordmark
            Spacer(minLength: 0)
            // The chip keeps FotMob's grouped-capsule chrome (Andy,
            // 2026-08-29) even alone: the capsule carries the tap target,
            // the pill paints its own fill only when active.
            LiveFilterChip(liveOnly: liveOnly, onToggle: onToggleLive)
                .padding(4)
                .glassCapsule(fallback: Color.bgElevated)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
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
        ScoresHeader(liveOnly: false, onToggleLive: {})
        ScoresHeader(liveOnly: true, onToggleLive: {})
    }
    .background(Color.bgPrimary)
}
