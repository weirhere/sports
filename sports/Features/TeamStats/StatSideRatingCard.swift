import SwiftUI

/// The StatSide rating's top three, leading college football's Top stats
/// (2026-10-25). The number beside each team is its record. The overall
/// scores at the top all sit near 97 or 98, so a fan reads more in 7-0 and
/// 6-1 (2026-10-28).
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
