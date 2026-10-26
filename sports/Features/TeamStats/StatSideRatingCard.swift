import SwiftUI

/// The StatSide rating's top three, leading college football's Top stats
/// (2026-10-25). The number beside each team is its record — the rating's
/// first two keys are losses and wins, so the record is the reason it
/// stands where it does.
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
                    TeamStatRow(team: row.team, value: row.record, isLeader: row.rank == 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }
}
