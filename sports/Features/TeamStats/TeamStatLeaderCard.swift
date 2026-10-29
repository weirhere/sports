import SwiftUI

/// One stat's card on the Team stats tab: its title, and the three teams
/// that lead it (2026-10-25, FotMob's league Team stats). The header is the
/// way to the whole table — `CardHeader`'s chevron — and each row is the
/// way to that team.
struct TeamStatLeaderCard: View {
    let destination: TeamStatRankingDestination

    private var rows: ArraySlice<TeamStatRanking.Row> {
        destination.ranking.rows.prefix(3)
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(value: destination) {
                CardHeader(title: destination.ranking.definition.title, isLink: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows every team")
            ForEach(rows) { row in
                NavigationLink(value: row.team) {
                    TeamStatRow(team: row.team, value: row.display,
                                isLeader: row.rank == 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }
}
