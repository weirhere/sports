import SwiftUI

/// A team row with a follow star.
///
/// Two shapes, because the two surfaces ask different questions.
/// **Onboarding** asks "do I want this team?" and the whole row is the
/// toggle — a bigger target than the star alone, which is what a
/// rapid-multi-select moment wants. The **Add teams sheet** asks the same
/// question of someone who may not know the answer yet, so its rows open
/// the team (Andy, 2026-09-09: "tapping the team name should take the user
/// to the team page. only tapping the star should favorite") and the star
/// keeps the follow to itself.
///
/// At accessibility text sizes the nickname drops under the location instead
/// of the two splitting one line into a pair of ellipses.
struct TeamFollowRow: View {
    let team: Team
    /// Set where the surrounding list spans leagues — a search result set.
    /// Inside a league's own section the tag would repeat the heading above.
    var leagueTag: League? = nil
    /// True where the row's body is a way into the team rather than a
    /// second, wider follow toggle. The surrounding stack must register a
    /// `Team` navigation destination.
    var opensTeam: Bool = false

    @Environment(FollowingStore.self) private var following
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }
    private var isFollowing: Bool { following.isFollowing(team) }

    var body: some View {
        if opensTeam { splitRow } else { wholeRowToggle }
    }

    /// The sheet's shape: the body opens the team, the star follows it.
    private var splitRow: some View {
        HStack(spacing: Spacing.md) {
            NavigationLink(value: team) {
                HStack(spacing: Spacing.md) {
                    identity
                    Spacer(minLength: Spacing.sm)
                    leagueTagText
                }
                .contentShape(Rectangle())
            }
            // A full-width surface is wider than any swipe, so `.plain`
            // would fire on the way out of one.
            .buttonStyle(SwipeSafeButtonStyle())
            .accessibilityLabel(spokenLabel)
            .accessibilityHint("Opens the team")
            star
                .accessibilityLabel(isFollowing ? "Unfollow \(team.location)"
                                                : "Follow \(team.location)")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
        // One of the budgeted three (follow toggle).
        .sensoryFeedback(.impact(weight: .light), trigger: isFollowing)
    }

    @ViewBuilder
    private var identity: some View {
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
    }

    private var star: some View {
        Button {
            following.toggle(team)
        } label: {
            Image(systemName: isFollowing ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundStyle(.textPrimary)
                // A star is a small mark; the target around it is not.
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isFollowing ? "following" : "not following")
    }

    private var wholeRowToggle: some View {
        Button {
            following.toggle(team)
        } label: {
            HStack(spacing: Spacing.md) {
                identity
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
