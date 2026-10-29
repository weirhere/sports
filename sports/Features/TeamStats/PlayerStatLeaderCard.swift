import SwiftUI

/// One stat's card on the Player stats tab: its title over the three
/// players who lead it (2026-10-26). `TeamStatLeaderCard`'s shape — the
/// header opens the whole table, each row the player's page.
struct PlayerStatLeaderCard: View {
    let destination: PlayerStatRankingDestination

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(value: destination) {
                CardHeader(title: destination.ranking.definition.title, isLink: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows every player")
            ForEach(destination.ranking.rows.prefix(3)) { row in
                NavigationLink(value: row.player.identity) {
                    PlayerStatRow(player: row.player, value: row.display, isLeader: row.rank == 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }
}
