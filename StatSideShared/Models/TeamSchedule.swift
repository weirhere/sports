import Foundation

/// One team's season: identity, record, and their games mapped into the
/// same Game domain the scoreboard uses.
nonisolated struct TeamSchedule: Sendable {
    let team: Team?
    let record: String?      // "12-1"
    let standing: String?    // "1st in SEC"
    let games: [Game]
}
