import SwiftUI

/// The News tab's Transfers page (Andy, 2026-10-19, after FotMob's): the
/// roster moves in every league's feed — trades, signings, waivers,
/// extensions, the portal — one to a card. `NewsStory.isTransaction`
/// decides, and it's a reading of the headline, so on a quiet day this
/// is a short page rather than a padded one.
struct NewsTransfersPage: View {
    let stories: [NewsStory]

    var body: some View {
        LazyVStack(spacing: Spacing.sm) {
            if stories.isEmpty {
                StatusMessage(text: "No transfer stories right now.")
                    .cardSurface()
            } else {
                StoryCardStack(stories: stories)
            }
        }
    }
}
