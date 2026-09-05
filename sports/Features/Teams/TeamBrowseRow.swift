import SwiftUI

/// One team in the browse list: logo, name, follow star. The row navigates;
/// the star doesn't.
///
/// At accessibility text sizes the nickname drops under the location instead
/// of the two splitting one line into a pair of ellipses.
struct TeamBrowseRow: View {
    let team: Team
    /// Set where the surrounding list spans leagues — the browse screen's
    /// search results. Inside a conference card the league is already the
    /// heading above, so the tag would repeat it.
    var leagueTag: League? = nil

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
                    leagueTagText
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel)
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

    var spokenLabel: String {
        let name = team.displayName ?? team.location
        guard let leagueTag else { return name }
        return "\(name), \(leagueTag.shortName)"
    }

    @ViewBuilder
    private var leagueTagText: some View {
        if let leagueTag {
            Text(leagueTag.shortName)
                .font(.meta)
                .tracking(0.4)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .fixedSize()
        }
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
