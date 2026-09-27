import SwiftUI

/// One story in a list: the photo small at the leading edge, the headline,
/// then who wrote it and how long ago (N7) — FotMob's row under its lead
/// card. The thumbnail is the row's "a page is behind this" cue; a story
/// ESPN sent no photo with falls back to the chevron `RosterRow` draws.
struct StoryRow: View {
    let story: NewsStory

    @ScaledMetric(relativeTo: .subheadline) private var thumbnailWidth: CGFloat = 96

    /// "AP · 2h ago", or nil when ESPN named nobody and dated nothing.
    static func meta(for story: NewsStory) -> String? {
        let parts = [story.attribution, story.published.map { NewsTimestamp.relative($0) }]
            .compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var meta: String? { Self.meta(for: story) }

    var body: some View {
        HStack(spacing: Spacing.md) {
            if story.imageURL != nil {
                StoryPhoto(url: story.imageURL)
                    .frame(width: thumbnailWidth, height: thumbnailWidth * 2 / 3)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(story.headline)
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                if let meta {
                    Text(meta)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if story.imageURL == nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([story.headline, meta].compactMap(\.self).joined(separator: ", "))
        .accessibilityHint("Opens the story")
    }
}
