import SwiftUI

#if canImport(ActivityKit)

/// The way a Live Activity starts: one game, pinned by hand from its own
/// detail page.
///
/// The NFL's shape, chosen over Apple Sports' per-team automatic (decision
/// 2026-09-10). A follow set spanning four leagues would put a wall of
/// cards on a September Saturday without anyone asking for one; a button
/// on the game you are already looking at cannot surprise anybody.
///
/// Monochrome, like every other state in the app's chrome: the filled pin
/// says on and the outlined one says off. Green is live-ness and nothing
/// else, so a pinned-but-not-yet-kicked game has no business wearing it.
struct GameActivityPinButton: View {
    let game: Game
    let summary: GameSummary?

    @State private var controller = LiveActivityController()
    @State private var isPinned = false
    @State private var isWorking = false

    /// Three gates, in the order they can fail. The feature flag first
    /// (there is no service yet), then the user's own Settings switch — a
    /// control that silently does nothing is worse than no control — then
    /// whether this particular game is one a card can speak for.
    private var isOffered: Bool {
        LiveActivityController.isAvailable
            && controller.areActivitiesEnabled
            && LiveActivityController.isStartable(game, summary: summary)
    }

    var body: some View {
        if isOffered {
            Button {
                Task { await toggle() }
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(.textPrimary)
            }
            .disabled(isWorking)
            .accessibilityLabel(isPinned
                                ? "Stop showing this game on the lock screen"
                                : "Show this game on the lock screen")
            // Not a fifth haptic. Pinning is the follow toggle's class of
            // event — one deliberate tap that turns a persistent thing on
            // or off — so it reuses that exact feedback rather than
            // inventing one. The budget of four counts kinds of moment,
            // and this is a moment the budget already has.
            .sensoryFeedback(.impact(weight: .light), trigger: isPinned)
            .task { await sync() }
        }
    }

    private func toggle() async {
        isWorking = true
        defer { isWorking = false }
        if isPinned {
            await controller.end(gameId: game.id)
        } else {
            _ = await controller.start(game: game, summary: summary)
        }
        await sync()
    }

    /// `Activity.activities` is a system-wide list rather than anything
    /// observable, so the button reads it rather than trusting its own
    /// memory — a card dismissed from the lock screen must not leave this
    /// showing a filled pin.
    private func sync() async {
        isPinned = controller.isActive(gameId: game.id)
    }
}
#endif
