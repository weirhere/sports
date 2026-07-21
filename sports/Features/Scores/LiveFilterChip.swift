import SwiftUI

/// The one filter in the app: tap to show only live games. Appears only
/// while games are live (or while the filter is already on).
struct LiveFilterChip: View {
    let liveOnly: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
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
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(liveOnly ? Color.textPrimary : Color.bgElevated)
                )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }
}
