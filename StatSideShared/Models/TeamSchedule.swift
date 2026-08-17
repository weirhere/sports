import Foundation

/// One team's season: identity, record, and their games mapped into the
/// same Game domain the scoreboard uses.
nonisolated struct TeamSchedule: Sendable {
    let team: Team?
    /// Provider's record summary ("12-1"). Nil when the provider's summary
    /// describes a different season than `games` (ESPN's tracks the current
    /// one) — use `derivedRecord` then.
    let record: String?
    let standing: String?    // "1st in SEC"
    /// The season the games belong to (ESPN's `requestedSeason.year`).
    /// May differ from the season asked for only via the nil-year
    /// current-season fallback, never for an explicitly requested year.
    let year: Int?
    let games: [Game]

    /// W-L counted from final results — the only honest record for a past
    /// season. Nil until at least one game is final (or when the team's
    /// identity is unknown, since wins can't be attributed).
    var derivedRecord: String? {
        guard let id = team?.id else { return nil }
        var wins = 0, losses = 0
        for game in games {
            guard case .final = game.status,
                  let mine = [game.home, game.away].first(where: { $0.team.id == id }),
                  let won = mine.winner
            else { continue }
            if won { wins += 1 } else { losses += 1 }
        }
        return wins + losses > 0 ? "\(wins)-\(losses)" : nil
    }
}
