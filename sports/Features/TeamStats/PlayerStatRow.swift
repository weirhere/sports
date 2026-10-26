import SwiftUI

/// One player in a stat table: headshot with the team's mark on its
/// corner, name, the number (2026-10-26). `TeamStatRow`'s columns with a
/// person in them. The mark is small and stacked on the headshot, FotMob's
/// badge, so the face leads and the team still reads at a glance (Andy,
/// 2026-10-26: no position, no team abbreviation line).
struct PlayerStatRow: View {
    let player: LeaguePlayer
    let value: String
    /// The place column. Nil on the leader cards.
    var rank: Int? = nil
    var isLeader = false

    @Environment(FollowingStore.self) private var following
    @ScaledMetric(relativeTo: .subheadline) private var headshotSize: CGFloat = 32
    /// The badge's disc and the mark inside it: small enough not to
    /// compete with the face.
    @ScaledMetric(relativeTo: .subheadline) private var badgeSize: CGFloat = 16
    @ScaledMetric(relativeTo: .subheadline) private var badgeLogoSize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var rankWidth: CGFloat = 22

    private var isFollowed: Bool { following.isFollowing(player.team) }

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let rank {
                Text("\(rank)")
                    .font(.metaEmphasis.monospacedDigit())
                    .foregroundStyle(.textSecondary)
                    .frame(minWidth: rankWidth, alignment: .trailing)
            }
            avatar
            Text(player.name)
                .font(isFollowed ? .teamNameEmphasis : .teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            Spacer(minLength: Spacing.sm)
            StatValueLabel(value: value, isLeader: isLeader, isEmphasized: isFollowed)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        // The mark is a picture; the label still says whose player.
        .accessibilityLabel([rank.map { "Number \($0)" }, player.name, player.team.location, value]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint("View player page")
    }

    /// The headshot, with the team's mark on a card-colored disc at its
    /// bottom-right corner — the disc is what keeps a dark mark readable
    /// over a photo, and it reaches a couple of points past the circle so
    /// the two read as stacked rather than printed on.
    private var avatar: some View {
        LogoImage(url: player.headshotURL?.headshotThumbnail ?? player.headshotURL, contentMode: .fill)
            .frame(width: headshotSize, height: headshotSize)
            .background(Circle().fill(Color.bgElevated))
            .clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                LogoImage(url: player.team.logoURL, placeholder: nil)
                    .frame(width: badgeLogoSize, height: badgeLogoSize)
                    .frame(width: badgeSize, height: badgeSize)
                    .background(Circle().fill(Color.bgCard))
                    .offset(x: 3, y: 3)
            }
    }
}
