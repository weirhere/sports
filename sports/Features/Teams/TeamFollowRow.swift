import SwiftUI

/// A team row whose whole width is the follow toggle — the shape both
/// pick-your-teams surfaces want (onboarding, and the Add teams sheet),
/// where the question is "do I want this team?", not "show me this team".
/// A bigger target than the star alone, which is what a joining moment
/// wants.
///
/// At accessibility text sizes the nickname drops under the location instead
/// of the two splitting one line into a pair of ellipses.
struct TeamFollowRow: View {
    let team: Team
    /// Set where the surrounding list spans leagues — a search result set.
    /// Inside a league's own section the tag would repeat the heading above.
    var leagueTag: League? = nil

    @Environment(FollowingStore.self) private var following
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }
    private var isFollowing: Bool { following.isFollowing(team) }

    var body: some View {
        Button {
            following.toggle(team)
        } label: {
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
                Image(systemName: isFollowing ? "star.fill" : "star")
                    .font(.system(size: 16))
                    .foregroundStyle(.textPrimary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        // Flattening the row hands the label and value to a plain
        // container, which drops the button trait the Button underneath
        // had — VoiceOver would announce the row without saying it can be
        // activated. Put it back.
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(spokenLabel)
        .accessibilityValue(isFollowing ? "following" : "not following")
        // One of the budgeted three (follow toggle).
        .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
    }

    private var spokenLabel: String {
        let name = team.displayName ?? team.location
        guard let leagueTag else { return name }
        return "\(name), \(leagueTag.shortName)"
    }

    private var locationText: some View {
        Text(team.location)
            .font(isFollowing ? .teamNameEmphasis : .teamName)
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
}
