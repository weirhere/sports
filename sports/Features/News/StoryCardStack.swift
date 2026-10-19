import SwiftUI

/// Stories one to a card, full width, stacked (FotMob's Latest, Mobbin
/// `bfd98a17`): the photo on top, the headline and byline under it. The
/// News tab's Latest and Transfers pages, and each league's share of its
/// Leagues page (Andy, 2026-10-19: "image on top, text on bottom", never
/// the thumbnail row).
///
/// No stack of its own: the caller's `LazyVStack` spaces the cards, so a
/// page can put headings between runs of them.
struct StoryCardStack: View {
    let stories: [NewsStory]

    var body: some View {
        ForEach(stories) { story in
            NavigationLink(value: StoryDestination(story: story)) {
                FeaturedStory(story: story)
            }
            .buttonStyle(.plain)
            .cardSurface()
        }
    }
}
