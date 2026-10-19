import SwiftUI

/// One league on the News tab's Leagues page: its mark and name as the
/// heading, then one `StorySection` — the newest story with a photo at
/// full width, four rows under it, and "See more" to the league's own
/// News tab (the Top 25 for college football, the league-wide conference
/// page for the rest). The same shape as a For you team section (Andy,
/// 2026-10-19: "1 featured, 4 standard, See more"), superseding the stack
/// of single-story cards this page opened with the same day.
struct NewsLeagueSection: View {
    let league: League
    let stories: [NewsStory]
    /// The snapshot suite renders without the mark: a league's logo is a
    /// real URL, and whether the image cache is warm decided the pixels.
    var showsLogo = true

    var body: some View {
        if showsLogo {
            NewsSectionHeading(logoURL: league.logoURL, title: league.displayName)
        } else {
            NewsSectionHeading(title: league.displayName)
        }
        if stories.isEmpty {
            StatusMessage(text: "No \(league.shortName) stories right now.")
                .cardSurface()
        } else if league == .collegeFootball {
            StorySection(stories: stories,
                         seeMore: PollDestination(league: league, opensNews: true))
        } else if let id = Conference.leagueWideId(in: league) {
            StorySection(stories: stories,
                         seeMore: ConferenceDestination(conference: ConferenceID(league, id),
                                                        name: Conference.name(for: id, in: league),
                                                        opensNews: true))
        } else {
            StorySection(stories: stories)
        }
    }
}
