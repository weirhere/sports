import SwiftUI

/// One team in the StatSide rating's full table: place, mark, name, then
/// the four numbers it's sorted on — W-L, differential, points for and
/// against — in `RankRow`'s columns.
struct StatSideRatingRow: View {
    let row: StatSideRating.Row

    @Environment(FollowingStore.self) private var following
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20
    @ScaledMetric(relativeTo: .subheadline) private var rankWidth: CGFloat = 22
    @ScaledMetric(relativeTo: .subheadline) private var recordWidth: CGFloat = 36
    @ScaledMetric(relativeTo: .subheadline) private var numberWidth: CGFloat = 34

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
            number(row.differentialDisplay)
            number("\(row.pointsFor)")
            number("\(row.pointsAgainst)")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Number \(row.rank), \(row.team.location), "
            + "\(row.wins) and \(row.losses), point differential \(row.differentialDisplay), "
            + "\(row.pointsFor) for, \(row.pointsAgainst) against")
        .accessibilityHint("View team page")
    }

    private func number(_ text: String) -> some View {
        Text(text)
            .font(.teamName.monospacedDigit())
            .foregroundStyle(.textSecondary)
            .frame(minWidth: numberWidth, alignment: .trailing)
    }
}
