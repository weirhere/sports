import SwiftUI

/// The StatSide rating's top three, leading college football's Top stats
/// (2026-10-25). The number beside each team is its overall score, the
/// number the list is sorted on, as every other stat card shows its own
/// (Andy, 2026-10-28).
struct StatSideRatingCard: View {
    let destination: StatSideRatingDestination

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(value: destination) {
                CardHeader(title: "StatSide rating", isLink: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the full rating")
            ForEach(destination.rows.prefix(3)) { row in
                NavigationLink(value: row.team) {
                    TeamStatRow(team: row.team, value: row.scoreDisplay, isLeader: row.rank == 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }
}
