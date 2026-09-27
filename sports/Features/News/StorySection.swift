import SwiftUI

/// A section of stories in one card (Andy, 2026-09-27, from FotMob's For
/// you, Mobbin `bfd98a17`): the first story featured at full width, the
/// next four as `StoryRow`s, then a "See more" row to the page that holds
/// the rest. For you's Trending and team sections, and each league page of
/// the News tab.
///
/// `seeMore` is a navigation value, so the push goes by value like every
/// other in the app; nil draws no row.
struct StorySection<Destination: Hashable>: View {
    let stories: [NewsStory]
    let seeMore: Destination?

    init(stories: [NewsStory], seeMore: Destination) {
        self.stories = stories
        self.seeMore = seeMore
    }

    /// The featured story and the four under it.
    static var size: Int { NewsFeedStore.sectionSize }

    /// The featured spot goes to the newest story with a photo, so the
    /// full-width card always has one; the rest keep their order.
    static func arranged(_ stories: [NewsStory]) -> [NewsStory] {
        guard let index = stories.firstIndex(where: { $0.imageURL != nil }), index > 0 else {
            return Array(stories.prefix(size))
        }
        var rest = stories
        let lead = rest.remove(at: index)
        return Array(([lead] + rest).prefix(size))
    }

    var body: some View {
        let shown = Self.arranged(stories)
        VStack(spacing: 0) {
            if let lead = shown.first {
                NavigationLink(value: StoryDestination(story: lead)) {
                    FeaturedStory(story: lead)
                }
                .buttonStyle(.plain)
            }
            ForEach(shown.dropFirst()) { story in
                Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                NavigationLink(value: StoryDestination(story: story)) {
                    StoryRow(story: story)
                }
                .buttonStyle(.plain)
            }
            if let seeMore {
                Divider().overlay(Color.divider)
                NavigationLink(value: seeMore) {
                    HStack {
                        Text("See more")
                            .font(.teamNameEmphasis)
                            .foregroundStyle(.textPrimary)
                        Spacer(minLength: Spacing.sm)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.textSecondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, seeMore == nil ? Spacing.xs : 0)
        .cardSurface()
    }
}

extension StorySection where Destination == Never {
    /// A section with nowhere further to go: For you's Trending.
    init(stories: [NewsStory]) {
        self.stories = stories
        self.seeMore = nil
    }
}
