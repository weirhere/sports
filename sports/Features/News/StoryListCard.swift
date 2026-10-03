import SwiftUI

/// A list of stories in one card of `StoryRow`s with the roster's inset
/// dividers — the team page's News tab (N9) and the News tab's feeds (E26).
///
/// `gameFor` hands each row the game its story is about where the page has
/// it, so the reader's score row can open that game (N5).
struct StoryListCard: View {
    let stories: [NewsStory]
    var gameFor: (NewsStory) -> Game? = { _ in nil }

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: "Latest")
            LazyVStack(spacing: 0) {
                ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                    // `.plain`, matching the roster in the same swipeable pane.
                    NavigationLink(value: StoryDestination(story: story, game: gameFor(story))) {
                        StoryRow(story: story)
                    }
                    .buttonStyle(.plain)
                    if index < stories.count - 1 {
                        Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                    }
                }
            }
            .padding(.top, Spacing.xs)
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }
}
