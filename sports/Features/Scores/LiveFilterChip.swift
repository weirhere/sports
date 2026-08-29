import SwiftUI

/// Tap to show only live games. A permanent header fixture (2026-08-29):
/// a stable home beats appearing mid-Saturday, and toggling it on a quiet
/// Tuesday lands on the explanatory empty state, not a hidden chip.
///
/// Styled as the leading pill of the header's grouped control (FotMob's
/// tap-target language, Andy 2026-08-29) — the enclosing capsule belongs
/// to `ScoresHeader`, so this pill paints only its active fill.
struct LiveFilterChip: View {
    let liveOnly: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                // The red dot is the filter's "on" light — off shows gray,
                // so the accent only spends when the toggle is live.
                Circle()
                    .fill(liveOnly ? Color.liveAccent : Color.textSecondary)
                    .frame(width: 7, height: 7)
                Text("Live")
                    .font(.chipEmphasis)
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(liveOnly ? Color.bgPrimary : Color.textPrimary)
            .padding(.horizontal, Spacing.md + 2)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(liveOnly ? Color.textPrimary : Color.clear)
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Live games only")
        .accessibilityAddTraits(liveOnly ? .isSelected : [])
    }
}
