import SwiftUI

/// The News tab's Latest page (Andy, 2026-10-19): every league's stories
/// newest first, previews last, one to a card. The section that closed
/// For you until then, given its own tab and taken off For you.
struct NewsLatestPage: View {
    let stories: [NewsStory]

    var body: some View {
        LazyVStack(spacing: Spacing.sm) {
            if stories.isEmpty {
                StatusMessage(text: "No stories right now.")
                    .cardSurface()
            } else {
                StoryCardStack(stories: stories)
            }
        }
    }
}
