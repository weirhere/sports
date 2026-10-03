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
            ForEach(stats.categoriesWithLines) { category in
                StatTableCard(
                    title: category.title,
                    columns: category.labels,
                    spokenColumns: category.displayNames,
                    rows: category.seasons.map(row),
                    footer: category.career.isEmpty ? nil
                        : StatTableCard.Row(id: "career", title: "Career", values: category.career),
                    leadsWithTeam: true)
            }
        }
    }

    /// The club's logo and name over the season, FotMob's career row
    /// (Andy, 2026-10-03). The name is the short one ("Georgia", "Chiefs")
    /// so the stats still fit beside it. A club the directory can't
    /// resolve (a college player's old school outside the fetched
    /// divisions) keeps the payload's own name and an empty logo disc; a
    /// line with no club at all is titled by its season alone.
    private func row(_ line: PlayerStats.SeasonLine) -> StatTableCard.Row {
        let team = line.teamId.flatMap { directory.team(matching: TeamRef(id: $0, league: league)) }
        guard let name = team.map({ $0.shortDisplayName ?? $0.location }) ?? line.teamName,
              !name.isEmpty else {
            return StatTableCard.Row(id: line.id, title: line.label, values: line.values)
        }
        return StatTableCard.Row(id: line.id, title: name, subtitle: line.label,
                                 values: line.values, logoURL: team?.logoURL)
    }
}
