import Foundation

/// One assistant on a team's staff, from `coaches.json` (2026-10-03).
///
/// ESPN lists head coaches only, so the coordinators come from Wikipedia
/// through `scripts/build-coaches.py`. No ESPN id, so no photo and no page:
/// a name and the role as Wikipedia words it.
nonisolated struct StaffCoach: Sendable, Hashable, Decodable {
    let name: String
    /// "Offensive coordinator", "Assistant head coach/special teams
    /// coordinator", "Quarterbacks coach".
    let role: String
}

/// The whole file: per league (`League.pathSegment`), per ESPN team id.
/// Every field optional, the ESPN rule applied to our own file too: a
/// malformed entry drops that team, never the decode.
nonisolated struct CoachStaffFile: Sendable, Decodable {
    /// "2026-10-03" — moves only when a staff did, so newer-wins compares
    /// as strings.
    let updated: String?
    let leagues: [String: [String: Entry]]?

    nonisolated struct Entry: Sendable, Decodable {
        /// The Wikipedia page the staff was read from.
        let source: String?
        let staff: [StaffCoach]?
    }

    func staff(league: League, teamId: String) -> [StaffCoach] {
        leagues?[league.pathSegment]?[teamId]?.staff ?? []
    }
}
