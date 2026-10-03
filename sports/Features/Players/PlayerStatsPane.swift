import SwiftUI

/// The Stats tab: one season, category by category, in ESPN's own words —
/// "Passing Yards 566" rather than "YDS 566", because a label/value card
/// has the room a table header doesn't.
///
/// **A season chip flips through every season the player has a line for**
/// (Andy, 2026-10-03, from FotMob's Stats tab). The data was always here —
/// it's the same request the Career tab tables — so the chip costs no
/// fetch. It's `SeasonMenuChip`, the Games tab's control, so the page's two
/// season pickers read as one, and it hides for a one-season player.
///
/// The default is the *latest* season with a line, not strictly the current
/// one: in the NBA's summer the current season has no games yet, and an
/// empty tab would hide numbers that are only four months old. The card's
/// subtitle says which season it is, so nothing passes for this year that
/// isn't.
struct PlayerStatsPane: View {
    let stats: PlayerStats
    let league: League
    /// ESPN's season year being shown; nil is the latest. Owned by the page
    /// so a trip to another tab and back keeps the pick, as the Games
    /// tab's season does.
    @Binding var season: Int?

    /// Every ESPN year any category has a line for, newest first.
    private var years: [Int] {
        Set(stats.categoriesWithLines.flatMap { $0.seasons.map(\.year) }).sorted(by: >)
    }

    private var shownYear: Int? {
        if let season, years.contains(season) { return season }
        return years.first
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if years.count > 1, let shownYear {
                HStack {
                    SeasonMenuChip(current: league.seasonYear(fromESPN: shownYear),
                                   seasons: years.map(league.seasonYear(fromESPN:)),
                                   league: league) { year in
                        season = league.espnSeason(for: year)
                    }
                    Spacer()
                }
            }
            if let shownYear {
                ForEach(stats.categoriesWithLines) { category in
                    // Usually one line; a player traded or transferred
                    // mid-season has one per club, each its own card.
                    ForEach(category.lines(for: shownYear)) { line in
                        LabeledValueCard(title: category.title,
                                         subtitle: [line.label, line.teamName].compactMap(\.self)
                                            .joined(separator: " · "),
                                         rows: rows(category, line))
                    }
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
