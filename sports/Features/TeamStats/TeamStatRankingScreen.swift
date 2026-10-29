import SwiftUI

/// Every team in one stat, best first — where a leader card's header goes
/// (2026-10-25). Tied teams share a place.
struct TeamStatRankingScreen: View {
    let destination: TeamStatRankingDestination

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CardHeader(title: destination.scopeName, subtitle: destination.seasonLabel)
                LazyVStack(spacing: 0) {
                    ForEach(destination.ranking.rows) { row in
                        NavigationLink(value: row.team) {
                            TeamStatRow(team: row.team, value: row.display, rank: row.rank,
                                        isLeader: row.rank == 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, Spacing.xs)
            .cardSurface()
            .padding(Spacing.sm)
        }
        .background(Color.bgRecessed)
        .navigationTitle(destination.ranking.definition.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
