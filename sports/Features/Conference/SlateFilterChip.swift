import SwiftUI

/// The Games tab's view toggles — "Weeks" and "Date" (Andy, 2026-09-05):
/// on/off, no chevron, because there is no menu behind them and a chevron
/// would promise one. The team chip beside them keeps its dropdown.
///
/// Glass at rest like every other chrome chip, a solid ink fill when on —
/// `ScoreFilterChip`'s rule (2026-08-29), so a reshaped pane is never a
/// mystery state. Glass never carries the on state, because a tinted glass
/// capsule reads as "maybe on" beside a filled one.
struct SlateToggleChip: View {
    let title: String
    let isOn: Bool
    var hint: String?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(title)
                .font(.chip)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isOn ? Color.bgPrimary : Color.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 8)
                .modifier(SlateChipBackground(isActive: isOn))
                // Compact capsule, 44 pt tap target.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("slate-toggle-\(title.lowercased())")
    }
}

/// Shared by the toggles and the team dropdown so the row reads as one set
/// of controls.
struct SlateChipBackground: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.background(Capsule().fill(Color.textPrimary))
        } else {
            content.glassCapsuleInteractive(fallback: Color.bgElevated)
        }
    }
}

#Preview {
    HStack(spacing: Spacing.sm) {
        SlateToggleChip(title: "Weeks", isOn: true, onToggle: {})
        SlateToggleChip(title: "Date", isOn: false, onToggle: {})
    }
    .padding()
    .background(Color.bgRecessed)
}

/// The Games tab's control row, on every page that has one: the two view
/// toggles and the team filter (Andy, 2026-09-05 — "these filters need to
/// go on all leagues/conferences pages"). One component, so a conference,
/// a league and the Top 25 all shape their slate the same way.
///
/// A plain row, not a scroller: three short chips fit, and a horizontal
/// ScrollView clipped the chips' own shadows at its bounds.
struct SlateControlRow: View {
    let grouping: ConferenceSlate.Grouping
    let onToggle: (ConferenceSlate.Grouping) -> Void
    /// Empty hides the team chip — one team is nothing to choose between,
    /// and none is nothing to choose from.
    var teams: [Team] = []
    var teamSelection: String?
    var onSelectTeam: (String?) -> Void = { _ in }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            SlateToggleChip(title: "Weeks", isOn: grouping == .week,
                            hint: "Groups the games by week") {
                onToggle(.week)
            }
            SlateToggleChip(title: "Date", isOn: grouping == .day,
                            hint: "Groups the games by day") {
                onToggle(.day)
            }
            if teams.count > 1 {
                ConferenceTeamFilterChip(teams: teams, selection: teamSelection,
                                         onSelect: onSelectTeam)
            }
            Spacer(minLength: 0)
        }
    }
}
