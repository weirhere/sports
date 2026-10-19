import SwiftUI

/// One team in a checklist: its mark, its name, and a check.
/// `TeamAlertRow`'s row with a logo where the glyph disc was — the News
/// tab's For you sheet (2026-10-19). Ink only: a filled check against an
/// empty ring reads without the green FotMob spends on it.
struct TeamCheckRow: View {
    let team: Team
    let isOn: Bool
    let toggle: () -> Void

    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 24

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: Spacing.md) {
                LogoImage(url: team.logoURL)
                    .frame(width: logoSize, height: logoSize)
                Text(team.displayName ?? team.location)
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
        .accessibilityLabel(team.displayName ?? team.location)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
