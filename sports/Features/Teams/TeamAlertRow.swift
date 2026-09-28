import SwiftUI

/// One checklist row in a team's notifications sheet: a glyph in a recessed
/// disc, the alert's name, and a check. FotMob's row, in ink: its green
/// check would spend color the budget doesn't have, and a filled check
/// against an empty ring reads without it.
struct TeamAlertRow: View {
    let alert: TeamAlert
    let league: League
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: Spacing.md) {
                Image(systemName: alert.symbol(in: league))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.bgRecessed, in: Circle())
                Text(alert.title(in: league))
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: Spacing.sm)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Color.textPrimary : Color.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(alert.title(in: league))
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
