import SwiftUI

/// The Stats tab: the player's latest season, category by category, in
/// ESPN's own words — "Passing Yards 566" rather than "YDS 566", because a
/// label/value card has the room a table header doesn't.
///
/// The *latest* season with a line, not strictly the current one: in the
/// NBA's summer the current season has no games yet, and an empty tab
/// would hide numbers that are only four months old. The card's subtitle
/// says which season it is, so nothing passes for this year that isn't.
struct PlayerStatsPane: View {
    let stats: PlayerStats

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(stats.categoriesWithLines) { category in
                if let line = category.seasons.last {
                    LabeledValueCard(title: category.title,
                                     subtitle: [line.label, line.teamName].compactMap(\.self)
                                        .joined(separator: " · "),
                                     rows: rows(category, line))
                }
            }
        }
    }

    private func rows(_ category: PlayerStats.Category,
                      _ line: PlayerStats.SeasonLine) -> [LabeledValueCard.Row] {
        category.labels.indices.compactMap { index in
            guard line.values.indices.contains(index) else { return nil }
            let fullName = category.displayNames.indices.contains(index)
                ? category.displayNames[index] : nil
            return LabeledValueCard.Row(label: fullName ?? category.labels[index],
                                        value: line.values[index],
                                        spokenLabel: fullName)
        }
    }
}
