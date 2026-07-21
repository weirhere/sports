import SwiftUI

/// The grouping toggle in the header, beside the season picker: off =
/// conference sections, on = one section per day. A view-mode switch,
/// not a filter — it never hides games.
struct GroupingChip: View {
    let byDate: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .medium))
                Text("By date")
                    .font(.chip)
            }
            .foregroundStyle(byDate ? Color.bgPrimary : Color.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(byDate ? Color.textPrimary : Color.bgElevated)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Group games by date")
        .accessibilityAddTraits(byDate ? .isSelected : [])
    }
}
