import SwiftUI

/// The Career tab: every season the player has a line for, with the club
/// they played it for, and ESPN's own career totals closing each table.
///
/// Nothing here is summed by the app (E20's Career row, 2026-09-20): the
/// seasons are ESPN's rows and the career line is ESPN's `totals`, so the
/// risks that row set out for a derived career — our numbers disagreeing
/// with theirs, a cost that scales with the career, silent holes — don't
/// arise. One request, the same one the Stats tab already made.
struct PlayerCareerPane: View {
    let stats: PlayerStats
    let league: League

    @Environment(TeamDirectoryStore.self) private var directory

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(stats.categories) { category in
                StatTableCard(
                    title: category.title,
                    columns: category.labels,
                    spokenColumns: category.displayNames,
                    rows: category.seasons.map { line in
                        StatTableCard.Row(id: line.id, title: line.label,
                                          subtitle: club(line), values: line.values)
                    },
                    footer: category.career.isEmpty ? nil
                        : StatTableCard.Row(id: "career", title: "Career", values: category.career))
            }
        }
    }

    /// "KC" — the directory's abbreviation where the club resolves, which it
    /// won't for a college player's old school outside the fetched divisions.
    private func club(_ line: PlayerStats.SeasonLine) -> String? {
        guard let id = line.teamId else { return nil }
        return directory.team(matching: TeamRef(id: id, league: league))?.abbreviation
    }
}
