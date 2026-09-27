import SwiftUI

/// One story in a list: the headline, then who wrote it and how long ago
/// (N7). Text only, by decision (N8): the rows every other news app leads
/// with a photo are the app's type hierarchy here, and the one image is the
/// chevron `RosterRow` draws for a row with a page behind it.
struct StoryRow: View {
    let story: NewsStory

    private var meta: String? {
        let parts = [story.attribution, story.published.map { NewsTimestamp.relative($0) }]
            .compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
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
            Spacer(minLength: Spacing.sm)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([story.headline, meta].compactMap(\.self).joined(separator: ", "))
        .accessibilityHint("Opens the story")
    }
}
