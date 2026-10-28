import SwiftUI

/// The StatSide rating, every FBS team: the Top 25, then everyone else
/// (2026-10-25). The rule sits under the table, because a rating nobody
/// can check is just another poll.
struct StatSideRatingScreen: View {
    let destination: StatSideRatingDestination

    private var topTier: [StatSideRating.Row] { destination.rows.filter(\.isInTopTier) }
    private var rest: [StatSideRating.Row] { destination.rows.filter { !$0.isInTopTier } }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                StatSideRatingTable(title: "Top 25", subtitle: destination.seasonLabel, rows: topTier)
                if !rest.isEmpty {
                    StatSideRatingTable(title: "Unranked", subtitle: destination.seasonLabel, rows: rest)
                }
                Text(StatSideRating.rule)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.sm)
            }
            .padding(Spacing.sm)
        }
        .background(Color.bgRecessed)
        .navigationTitle("StatSide rating")
        .navigationBarTitleDisplayMode(.inline)
    }
}
