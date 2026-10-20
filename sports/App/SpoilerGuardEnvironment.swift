import SwiftUI

extension EnvironmentValues {
    /// Spoiler mode's rule, for every view that draws a game (E30,
    /// 2026-10-19). `RootView` composes it from `SpoilerStore` and
    /// `FollowingStore`; `GameRow` reads it itself rather than being told
    /// by each of its callers, so a row in Search, News, a team's Next
    /// game card or the H2H list can't forget. Off by default, so a
    /// preview or a snapshot renders the score unless it asks not to —
    /// the `liveDotPulses` precedent.
    @Entry var spoilerGuard: SpoilerGuard = .off
}
