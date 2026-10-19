import SwiftUI

/// Spoiler mode's way out on the game page (E30, 2026-10-19): the capsule
/// that sits where the score would, under the one word of status, and
/// shows the result for good. `PollFollowPill`'s idiom — hairline capsule,
/// chip type, a glyph before the word — in the outline state only: it is
/// pressed once and then it is gone.
struct RevealScoreButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "eye")
                    .font(.system(size: 12))
                Text("Reveal score")
                    .font(.chip)
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .overlay(Capsule().strokeBorder(Color.textPrimary, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reveal score")
        .accessibilityIdentifier("game-reveal-score")
    }
}

#Preview {
    RevealScoreButton(action: {})
        .padding()
        .background(Color.bgCard)
}
