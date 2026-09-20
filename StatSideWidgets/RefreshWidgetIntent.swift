import AppIntents
import os
import WidgetKit

/// The widget footer's manual refresh: its ↻ and its timestamp are one
/// button, and tapping either re-asks ESPN now.
///
/// It exists because the scheduled cadence cannot be honest about a live
/// game. WidgetKit's reload budget is this app's politeness throttle
/// against the unofficial API (decision log, 2026-08-04), so a timeline can
/// ask for five minutes and be handed fifteen — and fifteen minutes of a Q2
/// drive is three scores. A reload a person asked for is the one reload the
/// budget does not charge for, which makes "I want it now" the single
/// request the app can always honour. The button is therefore the floor
/// under `GameSelection.liveInterval`'s ceiling, not a nicety beside it.
///
/// `perform()` does no fetching of its own: WidgetKit reloads the widget
/// that hosted the button once the intent returns, and the provider's own
/// `getTimeline` is the thing that knows how to build an entry. The
/// explicit reload below is belt-and-braces for the same reason every other
/// ESPN path in this app has a fallback — a button that silently does
/// nothing is worse than no button. Worst case it costs one duplicate
/// request per deliberate tap.
nonisolated struct RefreshWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Scores"
    static let description = IntentDescription("Fetch the latest scores for the teams you follow.")

    /// Widget chrome, not a Shortcuts action. There is nothing here worth
    /// automating, and a discoverable intent would sit in the Shortcuts
    /// library next to the app's one real one ("What's my next game?")
    /// offering to refresh a widget the user may not have placed.
    static let isDiscoverable = false
    static let openAppWhenRun = false

    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "widget")

    func perform() async throws -> some IntentResult {
        Self.logger.info("Manual widget refresh requested")
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
        return .result()
    }
}
