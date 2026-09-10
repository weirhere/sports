import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// One game, on the lock screen and in the Dynamic Island.
///
/// The split between this and `ContentState` is the split between what a
/// game *is* and what it's *doing*: ids, marks and abbreviations never
/// change once the card exists, so they ride here and are never pushed
/// again. Everything a score or a clock can move lives in the state.
///
/// Logo **URLs**, not bytes. An activity view renders once with no `.task`
/// and no `AsyncImage`, exactly like a widget view, so the view reads the
/// image synchronously off the App Group byte cache
/// (`WidgetLogoFetcher.cachedLogo(for:)`) and the starter pre-warms it.
/// Bytes in the state would also blow the 4KB budget a push update gets.
nonisolated struct GameActivityAttributes: ActivityAttributes {

    /// Everything that moves. Kept deliberately small — a broadcast push
    /// carries at most 4KB, and this has to fit with room to spare.
    nonisolated struct ContentState: Codable, Hashable {
        var awayScore: Int?
        var homeScore: Int?
        var phase: Phase

        /// The centre slot's headline: the kickoff time before the game,
        /// the clock during it, "Half" at a break, "Final" after.
        ///
        /// Formatted at the boundary rather than here, because
        /// `GameStatus.liveStatusText(in:)` is the app's one clock
        /// formatter and this must not become a sixth surface that
        /// re-derives it. See `GameActivityContent`.
        var headline: String

        /// The line under the headline: the network before kickoff, the
        /// live situation during a football game, nothing otherwise.
        var detail: String?

        /// When the facts above were true. Only rendered once the system
        /// tells us the card is stale — see `isStale` on the context.
        var asOf: Date

        /// Whether there is a score to show at all. Pre-kick this is
        /// false and the card shows no numbers: a 0–0 before kickoff is
        /// noise pretending to be signal, which the widget already ruled
        /// on (`WidgetGame.showsScores`).
        var showsScores: Bool { phase != .pre }
    }

    /// Which of the four centre states the card is in. Deliberately not
    /// `GameStatus`: that carries a clock, a period and a possession id
    /// this surface has already formatted away, and it isn't `Codable`.
    ///
    /// There is no `stale` case. Staleness is not a phase the game is in —
    /// it's a fact about our own freshness, and ActivityKit already tells
    /// the view via `context.isStale`.
    nonisolated enum Phase: String, Codable, Hashable, Sendable {
        case pre, live, intermission, final

        /// Green belongs to a clock that is actually running. A card at a
        /// break still reads live; a final does not.
        var isLive: Bool { self == .live || self == .intermission }
    }

    /// One side's fixed identity.
    nonisolated struct Side: Codable, Hashable, Sendable {
        let abbreviation: String
        /// Shown before kickoff only — the `GameRow` rule (2026-08-25).
        let record: String?
        let logo: URL?
        /// ESPN's `500-dark` variant. A lock screen sits over whatever
        /// wallpaper the user picked, so black artwork vanishing matters
        /// more here than anywhere in the app.
        let darkLogo: URL?
    }

    let gameId: String
    /// `League.rawValue`. The activity needs it to name periods correctly
    /// through `GameStatus.periodLabel(_:in:)` and to route the tap.
    let leagueToken: String
    let away: Side
    let home: Side
    /// Carried so the tap can land on the right day even when the game
    /// isn't in the five-day window the Scores screen holds — the
    /// `?day=` hint `DeepLinkURL.game(id:day:)` writes.
    let kickoff: Date?

    /// Where a tap on the card should land.
    var deepLink: URL? { DeepLinkURL.game(id: gameId, day: kickoff) }
}
#endif
