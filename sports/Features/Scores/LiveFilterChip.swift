import SwiftUI

/// The one filter in the app: tap to show only live games. A bare chip —
/// ScoresHeader owns layout and decides when it appears (only while games
/// are live, or while the filter is already on).
struct LiveFilterChip: View {
    let liveOnly: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.liveAccent)
                    .frame(width: 6, height: 6)
                Text("Live")
                    .font(.chip)
            }
            .foregroundStyle(liveOnly ? Color.bgPrimary : Color.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(liveOnly ? Color.textPrimary : Color.bgElevated)
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Live games only")
        .accessibilityAddTraits(liveOnly ? .isSelected : [])
    }
}
