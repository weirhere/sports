import SwiftUI

/// Tap to show only live games. A permanent header fixture (2026-08-29):
/// a stable home beats appearing mid-Saturday, and toggling it on a quiet
/// Tuesday lands on the explanatory empty state, not a hidden chip.
///
/// Styled as the leading pill of the header's grouped control (FotMob's
/// tap-target language, Andy 2026-08-29) — the enclosing capsule belongs
/// to `ScoresHeader`, so this pill paints only its active surface.
///
/// Active, it wears the accent rather than the ink (Andy, 2026-09-12, from
/// FotMob): a `liveTint` wash under a `liveEdge` hairline, `textPrimary`
/// staying put on top. The chip is the live affordance, so the live
/// accent's own exception covers it — one green, one token, and the dot
/// now sits on a surface it belongs to instead of vanishing into black.
struct LiveFilterChip: View {
    let liveOnly: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                // The dot is the filter's "on" light — off shows gray, so
                // the accent only spends when the toggle is live.
                Circle()
                    .fill(liveOnly ? Color.liveAccent : Color.textSecondary)
                    .frame(width: 8, height: 8)
                Text("Live")
                    .font(.chipEmphasis)
                    .lineLimit(1)
                    .fixedSize()
            }
            // The ink never inverts now, so the label holds its weight and
            // its contrast through the toggle — only the ground moves.
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, Spacing.md + 2)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(liveOnly ? Color.liveTint : Color.clear)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                liveOnly ? Color.liveEdge : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Live games only")
        .accessibilityIdentifier("scores-live-chip")
        .accessibilityAddTraits(liveOnly ? .isSelected : [])
    }
}
