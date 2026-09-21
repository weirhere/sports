import SwiftUI

/// Which league accordions are open on the Leagues hub — and only for as
/// long as the app is running (Andy, 2026-09-21).
///
/// **Closed by default**, where every other accordion in the app opens by
/// default. The hub is a list of leagues, not a list of contents: a Saturday
/// answer is "which league", and four expanded tables push the fourth league
/// off the screen before the question is asked.
///
/// **In memory, never `UserDefaults`.** The rule Andy asked for is precise —
/// an opened accordion survives switching tabs and survives backgrounding,
/// and resets when the app is force-quit — and that is exactly the lifetime
/// of a process. Writing it to disk would make it survive the force-quit
/// too, which is the one case where a reset is wanted: quitting is how
/// someone says "start me over". Nothing is persisted, so nothing has to be
/// migrated or cleaned up either.
///
/// Held by `RootView` rather than by `TablesScreen`, because a tab's content
/// is rebuilt when the tab is reselected and `@State` inside it would reset
/// on every visit — which is the "switches pages but comes back" half of
/// the rule.
///
/// Separate from `UIStateStore.collapsedConferences` on purpose: that set is
/// the Teams browse screen's, it is persisted, and it means the inverse
/// (absence is expanded). Sharing it would have flipped a screen nobody
/// asked about.
@Observable
@MainActor
final class LeagueSectionExpansion {
    private(set) var expanded: Set<String> = []

    func isExpanded(_ sectionId: String) -> Bool {
        expanded.contains(sectionId)
    }

    func toggle(_ sectionId: String) {
        if expanded.contains(sectionId) {
            expanded.remove(sectionId)
        } else {
            expanded.insert(sectionId)
        }
    }

    /// For a destination that has to show a section whatever its state —
    /// the same need `UIStateStore.expandConference` serves one screen over.
    func expand(_ sectionId: String) {
        expanded.insert(sectionId)
    }
}
