import Foundation

// `nonisolated` because the project defaults types to MainActor
// (SWIFT_DEFAULT_ACTOR_ISOLATION) and this is a pure function the Siri
// intent calls from outside the actor.
nonisolated extension Game {
    /// The live merge, in one place: replace a game with the scoreboard's
    /// copy of it when the scoreboard has one.
    ///
    /// Surfaces that show games they fetched from a *non-polling* endpoint
    /// — a team's schedule, a conference's season slate — carry no live
    /// scores or clock once a game kicks off, and never learn better on
    /// their own. The scoreboard polls every 30s and is the app's one live
    /// source, so those pages render through this instead of their own
    /// snapshot. A game the scoreboard hasn't loaded (any week but the
    /// selected one and its cached neighbours, or a past season) keeps the
    /// snapshot it came with.
    ///
    /// It lives here because it was written twice and fixed once: the
    /// dashed-score bug (Andy, 2026-08-29) was closed on TeamPage while
    /// ConferencePage's Games tab kept freezing live games at whatever
    /// score they held when the page opened.
    static func merging(_ games: [Game], withLive board: [Game]) -> [Game] {
        guard !games.isEmpty, !board.isEmpty else { return games }
        // A season slate is ~100 games and a full Saturday board is ~100
        // more; a linear scan per game would be 10k comparisons on every
        // body evaluation.
        let fresher = Dictionary(board.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return games.map { fresher[$0.id] ?? $0 }
    }

    /// The single-game form, for surfaces that merge one card.
    static func merging(_ game: Game, withLive board: [Game]) -> Game {
        board.first { $0.id == game.id } ?? game
    }
}
