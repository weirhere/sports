import SwiftUI

/// One league on the News tab's Leagues page: its mark and name as the
/// heading, "See more" at the heading's trailing edge, and its first
/// `NewsFeedStore.sectionSize` stories as stacked cards. "See more" opens
/// the league's own News tab — the Top 25 for college football, the
/// league-wide conference page for the rest — as the league tabs' did.
struct NewsLeagueSection: View {
    let league: League
    let stories: [NewsStory]

    var body: some View {
        NewsSectionHeading(logoURL: league.logoURL, title: league.displayName) {
            if !stories.isEmpty { seeMore }
        }
        if stories.isEmpty {
            StatusMessage(text: "No \(league.shortName) stories right now.")
                .cardSurface()
        } else {
            StoryCardStack(stories: Array(stories.prefix(NewsFeedStore.sectionSize)))
        }
    }

    @ViewBuilder
    private var seeMore: some View {
        if league == .collegeFootball {
            NavigationLink(value: PollDestination(league: league, opensNews: true)) { seeMoreLabel }
                .buttonStyle(.plain)
        } else if let id = Conference.leagueWideId(in: league) {
            NavigationLink(value: ConferenceDestination(conference: ConferenceID(league, id),
                                                        name: Conference.name(for: id, in: league),
                                                        opensNews: true)) { seeMoreLabel }
                .buttonStyle(.plain)
        }
    }

    private var seeMoreLabel: some View {
        HStack(spacing: Spacing.xs) {
            Text("See more")
                .font(.meta)
                .foregroundStyle(.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityLabel("See more \(league.spokenName) stories")
    }
}
