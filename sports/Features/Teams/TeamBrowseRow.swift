import SwiftUI

/// One team in the browse list: logo, name, follow star. The row navigates;
/// the star doesn't.
///
/// At accessibility text sizes the nickname drops under the location instead
/// of the two splitting one line into a pair of ellipses.
struct TeamBrowseRow: View {
    let team: Team

    @Environment(FollowingStore.self) private var following
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        HStack(spacing: Spacing.md) {
            NavigationLink(value: team) {
                HStack(spacing: Spacing.md) {
                    LogoImage(url: team.logoURL)
                        .frame(width: logoSize, height: logoSize)
                    if isStacked {
                        VStack(alignment: .leading, spacing: 2) {
                            locationText
                            nicknameText
                        }
                    } else {
                        locationText
                        nicknameText
                    }
                    Spacer(minLength: Spacing.sm)
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(team.displayName ?? team.location)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    following.toggle(team)
                } label: {
                    Label(following.isFollowing(team) ? "Unfollow \(team.location)" : "Follow \(team.location)",
                          systemImage: following.isFollowing(team) ? "star.slash" : "star")
                }
            }
            FollowButton(team: team)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 5)
    }

    private var locationText: some View {
        Text(team.location)
            .font(.teamName)
            .foregroundStyle(.textPrimary)
            .lineLimit(isStacked ? 2 : 1)
    }

    @ViewBuilder
    private var nicknameText: some View {
        if let nickname = team.name {
            Text(nickname)
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .lineLimit(isStacked ? 2 : 1)
        }
    }
}
