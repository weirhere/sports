import SwiftUI

/// The Starters section's title row, in both of its layouts: the title
/// (and, under it, which side is only projected), with the Field / List
/// chips trailing — on the section itself, because the field is what you
/// are looking at when you decide you'd rather have the list (Andy,
/// 2026-10-18). On the field the row sits on the surface's paint in its
/// ink; over the list cards it sits on the page in the page's.
struct StartersHeader: View {
    let roster: GameRoster
    let layout: StartersLayout
    let onLayoutChange: (StartersLayout) -> Void
    /// Set on the painted field; nil over the list cards.
    var ink: SurfaceColors.Ink? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(roster.startersTitle)
                    .font(.sectionHeader)
                    .foregroundStyle(ink?.text ?? Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle = roster.startersSubtitle {
                    Text(subtitle)
                        .font(.meta)
                        .foregroundStyle(ink?.text.opacity(0.75) ?? Color.textSecondary)
                }
            }
            Spacer(minLength: Spacing.sm)
            HStack(spacing: Spacing.xs) {
                ForEach(StartersLayout.allCases) { option in
                    SlateToggleChip(title: option.label, isOn: layout == option,
                                    hint: hint(for: option), ink: ink) {
                        onLayoutChange(option)
                    }
                }
            }
            .accessibilityIdentifier("starters-layout")
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
    }

    private func hint(for option: StartersLayout) -> String {
        switch option {
        case .field: "Draws the starters on the field"
        case .list: "Lists the starters in cards"
        }
    }
}

extension GameRoster {
    /// What the section calls the eleven, five or six it shows.
    var startersTitle: String {
        let kinds = [away.lineupKind, home.lineupKind]
        if kinds.contains(.onIce) { return "On the ice" }
        if kinds.contains(.declared) { return "Starters" }
        return "Projected starters"
    }

    /// One side declared, the other only projected: say so once.
    var startersSubtitle: String? {
        let kinds = [away.lineupKind, home.lineupKind]
        guard kinds.contains(.declared), kinds.contains(.projected) else { return nil }
        let projected = away.lineupKind == .projected ? away.team : home.team
        return "\(projected.abbreviation ?? projected.location) projected"
    }
}
