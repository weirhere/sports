import SwiftUI

/// Every player in one stat's pool, best first — where a player leader
/// card's header goes (2026-10-26). The pool is ESPN's qualified slice,
/// narrowed to the page's teams, so this is "everyone who counts", not
/// every name on a roster.
struct PlayerStatRankingScreen: View {
    let destination: PlayerStatRankingDestination

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CardHeader(title: destination.scopeName, subtitle: destination.seasonLabel)
                LazyVStack(spacing: 0) {
                    ForEach(destination.ranking.rows) { row in
                        NavigationLink(value: row.player.identity) {
                            PlayerStatRow(player: row.player, value: row.display, rank: row.rank,
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
