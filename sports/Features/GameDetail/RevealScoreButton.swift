import SwiftUI

/// Spoiler mode's way out on the game page (E30, 2026-10-19): the capsule
/// that shows the result for good, a full-width row of its own under the
/// header's records (283 — in the middle column it had a third of the
/// header and "Reveal score" broke onto two lines on every device; a row
/// of its own is the only place the label is guaranteed one line at the
/// SE's width). `PollFollowPill`'s idiom — hairline capsule, chip type, a
/// glyph before the word — in the outline state only: it is pressed once
/// and then it is gone.
struct RevealScoreButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "eye")
                    .font(.system(size: 12))
                Text("Reveal score")
                    .font(.chip)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
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
