import SwiftUI

/// One team in a stat table: logo, name, the number. The leader cards show
/// three of these and the full list shows them all, with a place column in
/// front (2026-10-25).
///
/// The leader's number sits in `StatValueLabel`'s capsule. Columns follow `RankRow`'s, so a team stat table reads like every other
/// table in the app.
struct TeamStatRow: View {
    let team: Team
    let value: String
    /// The place column. Nil on the leader cards, whose three rows are the
    /// top three by construction.
    var rank: Int? = nil
    var isLeader = false

    @Environment(FollowingStore.self) private var following
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20
    @ScaledMetric(relativeTo: .subheadline) private var rankWidth: CGFloat = 22

    private var isFollowed: Bool { following.isFollowing(team) }

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let rank {
                Text("\(rank)")
                    .font(.metaEmphasis.monospacedDigit())
                    .foregroundStyle(.textSecondary)
                    .frame(minWidth: rankWidth, alignment: .trailing)
            }
            LogoImage(url: team.logoURL)
                .frame(width: logoSize, height: logoSize)
            Text(team.location)
                .font(isFollowed ? .teamNameEmphasis : .teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            Spacer(minLength: Spacing.sm)
            StatValueLabel(value: value, isLeader: isLeader, isEmphasized: isFollowed)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rank.map { "Number \($0), \(team.location), \(value)" }
                            ?? "\(team.location), \(value)")
        .accessibilityHint("View team page")
    }
}
