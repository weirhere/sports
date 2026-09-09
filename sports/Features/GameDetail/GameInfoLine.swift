import SwiftUI

/// One icon-led line — the game-detail info cards' original row shape,
/// kept for the facts that are a single sentence each (kickoff, the
/// network, the forecast). Shared by the two cards that split out of
/// "Game info", so their rows stay the same row.
struct GameInfoLine: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.textSecondary)
                .frame(width: 20)
            Text(text)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
    }
}
