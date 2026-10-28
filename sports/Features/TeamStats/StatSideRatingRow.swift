import SwiftUI

/// One team in the StatSide rating's full table: place, mark, name, then
/// four numbers in `RankRow`'s columns. They are the record, the overall
/// score (0–100), and the résumé and performance ranks the score combines
/// two-thirds and one-third.
struct StatSideRatingRow: View {
    let row: StatSideRating.Row

    @Environment(FollowingStore.self) private var following
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20
    @ScaledMetric(relativeTo: .subheadline) private var rankWidth: CGFloat = 22
    @ScaledMetric(relativeTo: .subheadline) private var recordWidth: CGFloat = 36
    /// Wide enough for "98.2" and its caption, "SCORE".
    @ScaledMetric(relativeTo: .subheadline) private var scoreWidth: CGFloat = 40
    /// Wide enough for "138" and "PERF": the ranks are three digits at most.
    @ScaledMetric(relativeTo: .subheadline) private var placeWidth: CGFloat = 30

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("\(row.rank)")
                .font(.metaEmphasis.monospacedDigit())
                .foregroundStyle(.textSecondary)
                .frame(minWidth: rankWidth, alignment: .trailing)
            LogoImage(url: row.team.logoURL)
                .frame(width: logoSize, height: logoSize)
                .padding(.leading, Spacing.xs)
            Text(row.team.location)
                .font(following.isFollowing(row.team) ? .teamNameEmphasis : .teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .padding(.leading, Spacing.xs)
            Spacer(minLength: Spacing.xs)
            Text(row.record)
                .font(.teamNameEmphasis.monospacedDigit())
                .foregroundStyle(.textPrimary)
                .frame(minWidth: recordWidth, alignment: .trailing)
            number(row.scoreDisplay, width: scoreWidth)
            number("\(row.resumeRank)", width: placeWidth)
            number("\(row.performanceRank)", width: placeWidth)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Number \(row.rank), \(row.team.location), "
            + "\(row.wins) and \(row.losses), score \(row.scoreDisplay), "
            + "résumé \(row.resumeRank), performance \(row.performanceRank)")
        .accessibilityHint("View team page")
    }

    private func number(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.teamName.monospacedDigit())
            .foregroundStyle(.textSecondary)
            .frame(minWidth: width, alignment: .trailing)
    }
}
