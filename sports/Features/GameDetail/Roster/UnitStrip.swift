import SwiftUI

/// One football team's strip on the Starters field: its logo, then an
/// Offense and a Defense chip — the top team's under the title, the
/// bottom team's under the field (the Figma sheet "↳ Roster variants",
/// 2026-10-27). The two strips are one choice seen from both ends: a snap
/// has one offense, so the bottom strip always reads the opposite of the
/// top one, and a tap on either sets whose offense the field draws.
///
/// A hairline in the field's own paint sits above the strip, the shade
/// change doing the rest; the logo draws bare, with `LogoImage`'s white
/// sticker outline wherever the mark blends into the turf.
struct UnitStrip: View {
    let team: Team
    let opponent: Team
    let league: League
    /// Whether this team's offense is the one on the field.
    let isOffense: Bool
    let ink: SurfaceColors.Ink
    /// True for Offense, false for Defense.
    let onPick: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(SurfaceColors.base(for: league))
                .frame(height: 1)
            HStack(spacing: Spacing.sm) {
                LogoImage(url: team.logoURL,
                          outlineAgainst: SurfaceColors.hex(SurfaceColors.base(for: league),
                                                            isDark: colorScheme == .dark))
                    .frame(width: 28, height: 28)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                chip("Offense", isOn: isOffense,
                     hint: "Draws \(team.location)'s offense against \(opponent.location)'s defense") {
                    onPick(true)
                }
                chip("Defense", isOn: !isOffense,
                     hint: "Draws \(team.location)'s defense against \(opponent.location)'s offense") {
                    onPick(false)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.sm + Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    private func chip(_ title: String, isOn: Bool, hint: String, action: @escaping () -> Void) -> some View {
        SlateToggleChip(title: title, isOn: isOn, hint: hint, ink: ink,
                        accessibilityName: "\(team.abbreviation ?? team.location) \(title.lowercased())",
                        onToggle: action)
    }
}
