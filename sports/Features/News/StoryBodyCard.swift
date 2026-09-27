import SwiftUI

/// The story's text in one card, set in the app's own type: subheads in the
/// emphasis weight, paragraphs in the regular one. No new type token — a
/// reading size would be the first the app has, and 15pt is what every
/// other sentence in it is set in.
struct StoryBodyCard: View {
    let blocks: [StoryBlock]

    var body: some View {
        // Lazy: ESPN's longest pieces run to 500 paragraphs, and the card
        // sits inside the reader's ScrollView like the roster's groups do.
        LazyVStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let text):
                    Text(text)
                        .font(.teamNameEmphasis)
                        .foregroundStyle(.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Spacing.xs)
                case .paragraph(let text):
                    Text(text)
                        .font(.teamName)
                        .foregroundStyle(.textPrimary)
                        .lineSpacing(3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .padding(Spacing.lg)
        .cardSurface()
    }
}
