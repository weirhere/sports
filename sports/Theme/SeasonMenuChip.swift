import SwiftUI

/// The season picker: a capsule chip opening a menu of years, newest
/// first. Shared by the Scores header, TeamPage and ConferencePage so the
/// three read as one control.
struct SeasonMenuChip: View {
    let current: Int
    let seasons: [Int]
    /// Whose season this is. Football names a season by the year it opens
    /// and renders "2026"; the NBA and NHL name it by the year it ends and
    /// render "2026-27", which is ESPN's own spelling and the only one
    /// that isn't ambiguous about which winter you're looking at.
    var league: League = .collegeFootball
    let onSelect: (Int) -> Void

    private func label(_ year: Int) -> String { league.seasonLabel(year) }

    var body: some View {
        Menu {
            Picker("Season", selection: Binding(get: { current }, set: onSelect)) {
                ForEach(seasons, id: \.self) { year in
                    Text(label(year)).tag(year)
                }
            }
        } label: {
            label
        }
        .disabled(seasons.isEmpty)
        .accessibilityLabel("Season, \(label(current))")
        // A stable handle for the screenshot flow, which has to reach the
        // chip wherever it rides — the Scores strip or a tab pane.
        // Matching the spoken label instead would break every time the
        // wording moves.
        .accessibilityIdentifier("season-chip")
        .accessibilityValue(label(current))
    }

    /// Same capsule as the Scores header chips and the panes' other
    /// chips, so every chip over content reads as one family. (The `.bar`
    /// variant for the toolbar row retired 2026-09-27, when every entity
    /// page moved its season chip into the pane.)
    private var label: some View {
        content
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
            .glassCapsuleInteractive(fallback: Color.bgElevated)
            // Compact capsule, 44 pt tap target.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    private var content: some View {
        HStack(spacing: Spacing.xs) {
            Text(label(current))
                .font(.chip)
                .lineLimit(1)
                .fixedSize()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color.textPrimary)
    }
}

#Preview {
    SeasonMenuChip(
        current: 2026,
        seasons: Array(stride(from: 2026, through: 2014, by: -1)),
        onSelect: { _ in }
    )
    .padding()
    .background(Color.bgPrimary)
}
