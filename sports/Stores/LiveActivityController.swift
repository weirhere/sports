import Foundation
import os

#if canImport(ActivityKit)
import ActivityKit

/// Starts, updates and ends the one-game Live Activity.
///
/// **What this deliberately is not, yet.** Path 3 (broadcast push channels)
/// is the decided mechanism, and it needs the service that E12 sequences
/// after this. Until that exists every activity here is started with
/// `pushType: nil` and advanced by `update(...)` from the running app —
/// which is exactly path 1, and path 1 is rejected on the merits for users
/// (`docs/live-activities.md`). So this is buildable and reviewable on a
/// device, and it is gated off in front of users by `isAvailable` until the
/// channel id is real. Do not "finish" this by shipping it as-is.
@Observable
final class LiveActivityController {
    private let log = Logger(subsystem: "com.andyryanweir.sports", category: "liveactivity")

    /// Live only while a game is genuinely being pushed. Flipping this on
    /// without the service is the mistake the doc exists to prevent.
    static var isAvailable: Bool { false }

    /// Whether the OS will let us show one at all. Separate from
    /// `isAvailable`: the user can switch activities off in Settings, and a
    /// button that does nothing is worse than no button.
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Games we already have a card for, so starting twice is a no-op
    /// rather than two identical cards on one lock screen.
    var activeGameIds: Set<String> {
        Set(Activity<GameActivityAttributes>.activities.map(\.attributes.gameId))
    }

    func isActive(gameId: String) -> Bool { activeGameIds.contains(gameId) }

    // MARK: - Lifecycle

    @discardableResult
    func start(game: Game, summary: GameSummary? = nil) async -> Bool {
        guard areActivitiesEnabled, !isActive(gameId: game.id) else { return false }
        let attributes = LiveActivityContent.attributes(for: game)
        let state = LiveActivityContent.state(for: game, summary: summary)

        // Warm the App Group byte cache before the card can render: the
        // view reads logos synchronously and a cold cache renders discs.
        await warmLogos(attributes)

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: staleDate(for: state, game: game)),
                // E12: becomes `.channel(...)` once the broadcast service
                // exists. `nil` keeps this local-only and reviewable.
                pushType: nil
            )
            return true
        } catch {
            log.error("live activity request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func update(game: Game, summary: GameSummary? = nil) async {
        guard let activity = activity(for: game.id) else { return }
        let state = LiveActivityContent.state(for: game, summary: summary)
        await activity.update(
            ActivityContent(state: state, staleDate: staleDate(for: state, game: game))
        )
    }

    /// Ends the card on the same rule the widget clears a result on —
    /// `GameSelection.isSpent`, six hours' grace past midnight — rather than
    /// on a bare final, so a game that ends after midnight doesn't vanish
    /// the instant the whistle goes.
    func endIfSpent(game: Game, now: Date = .now) async {
        guard GameSelection.isSpent(game, now: now) else { return }
        await end(gameId: game.id, finalState: LiveActivityContent.state(for: game, now: now))
    }

    func end(gameId: String, finalState: GameActivityAttributes.ContentState? = nil) async {
        guard let activity = activity(for: gameId) else { return }
        let content = finalState.map { ActivityContent(state: $0, staleDate: nil) }
        await activity.end(content, dismissalPolicy: .default)
    }

    func endAll() async {
        for activity in Activity<GameActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Internals

    private func activity(for gameId: String) -> Activity<GameActivityAttributes>? {
        Activity<GameActivityAttributes>.activities.first { $0.attributes.gameId == gameId }
    }

    /// When the card should stop claiming to be current.
    ///
    /// Before kickoff there is nothing to go stale — every fact on the card
    /// was known when it was made — so the deadline is the kickoff itself.
    /// During play it is two poll intervals' grace: long enough to ride out
    /// one missed update, short enough that a dead service shows as stale
    /// rather than as a frozen score. A final never goes stale.
    private func staleDate(for state: GameActivityAttributes.ContentState,
                           game: Game) -> Date? {
        switch state.phase {
        case .pre:
            return game.date
        case .live, .intermission:
            return state.asOf.addingTimeInterval(120)
        case .final:
            return nil
        }
    }

    private func warmLogos(_ attributes: GameActivityAttributes) async {
        for url in [attributes.away.logo, attributes.away.darkLogo,
                    attributes.home.logo, attributes.home.darkLogo] {
            _ = await WidgetLogoFetcher.logo(for: url)
        }
    }
}
#endif
