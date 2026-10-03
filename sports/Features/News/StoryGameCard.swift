import SwiftUI

/// The reader's score row (N5): `NextGameCard`'s recipe, a header over the
/// Scores `GameRow` itself. A link to the game unless the reader was pushed
/// from that game's page, where the back button is the way there.
struct StoryGameCard: View {
    let game: Game
    let isLink: Bool

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: "Game")
            if isLink {
                NavigationLink(value: game) { GameRow(game: game) }
                    .buttonStyle(.plain)
            } else {
                GameRow(game: game)
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }
}
