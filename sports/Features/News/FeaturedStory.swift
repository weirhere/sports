import SwiftUI

/// A story at full width: the photo at 16:9, then the headline at
/// `storyFeatured` and who wrote it (FotMob's lead card, Mobbin
/// `bfd98a17`). A section's first story, and every story in For you's
/// Latest.
///
/// No card of its own: the section card or the Latest list decides the
/// surface. The photo runs to the card's edges, and the card's clip rounds
/// its top corners.
struct FeaturedStory: View {
    let story: NewsStory

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if story.imageURL != nil {
                StoryPhoto(url: story.imageURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(story.headline)
                    .font(.storyFeatured)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                if let meta = StoryRow.meta(for: story) {
                    Text(meta)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.md)
            // Without a photo the headline leads the card, so it needs
            // the top inset the photo gave it.
            .padding(.top, story.imageURL == nil ? Spacing.md : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([story.headline, StoryRow.meta(for: story)].compactMap(\.self)
            .joined(separator: ", "))
        .accessibilityHint("Opens the story")
    }
}
