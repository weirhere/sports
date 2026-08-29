import SwiftUI

/// The team page's lead card: the current season's next unplayed game —
/// or the one in progress, retitled "Current game". The body is the
/// Scores `GameRow` itself (Andy, 2026-08-29: "just reuse that same
/// component"): per-side scores while live, records while upcoming, and
/// the status column's clock + network, all speaking the row's own
/// VoiceOver sentence. Tapping pushes the game's detail.
struct NextGameCard: View {
    let game: Game

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: game.isLive ? "Current game" : "Next game")
            NavigationLink(value: game) {
                GameRow(game: game)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, Spacing.xs)
    }
}
