import SwiftUI

/// The StatSide rating, every FBS team: the Top 25, then everyone else, as
/// Andy's Performance Poll groups them (2026-10-25). The rule sits under
/// the table, because a rating nobody can check is just another poll.
struct StatSideRatingScreen: View {
    let destination: StatSideRatingDestination

    // `StatSideRatingRow`'s column widths, so the captions sit over them.
    @ScaledMetric(relativeTo: .subheadline) private var recordWidth: CGFloat = 36
    @ScaledMetric(relativeTo: .subheadline) private var numberWidth: CGFloat = 34

    private var topTier: [StatSideRating.Row] { destination.rows.filter(\.isInTopTier) }
    private var rest: [StatSideRating.Row] { destination.rows.filter { !$0.isInTopTier } }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                tier(title: "Top 25", rows: topTier)
                if !rest.isEmpty {
                    tier(title: "Unranked", rows: rest)
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

    private func tier(title: String, rows: [StatSideRating.Row]) -> some View {
        VStack(spacing: 0) {
            CardHeader(title: title, subtitle: destination.seasonLabel)
            captions
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    NavigationLink(value: row.team) {
                        StatSideRatingRow(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    /// The column captions over the four numbers, aligned to the row's
    /// trailing columns.
    private var captions: some View {
        HStack(spacing: Spacing.sm) {
            Spacer()
            caption("W-L", width: recordWidth)
            caption("DIFF", width: numberWidth)
            caption("PF", width: numberWidth)
            caption("PA", width: numberWidth)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .accessibilityHidden(true)
    }

    private func caption(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.rowMetaMedium)
            .foregroundStyle(.textSecondary)
            .frame(minWidth: width, alignment: .trailing)
    }
}
