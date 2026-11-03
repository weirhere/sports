import Foundation

/// A school's player now in the NFL, NBA or NHL, from `pros.json`
/// (2026-11-02) — one row of a college team page's Pros tab.
///
/// The file is `scripts/build-pros.py`'s walk of the 94 pro rosters, keyed
/// by the `college.id` ESPN puts on each athlete. That id is the school's
/// own, the same value as its college football team id, which is why the
/// tab looks itself up by the team page's id.
nonisolated struct ProAlumnus: Sendable, Hashable, Identifiable {
    let league: League
    let athleteId: String
    let name: String
    /// The pro team, by ESPN id in `league` — the directory turns it into a
    /// `Team` for the row's mark and the player page's badge.
    let teamId: String?
    /// "QB", "C", "G".
    let position: String?
    /// "Quarterback", for VoiceOver.
    let positionName: String?
    let jersey: String?
    let headshotURL: URL?

    /// `PlayerIdentity.id`'s namespacing, for the same reason: two leagues
    /// can reuse an athlete id, and one school can have a player in each.
    var id: String { "\(league.rawValue)-\(athleteId)" }

    var thumbnailURL: URL? { headshotURL?.headshotThumbnail ?? headshotURL }

    /// The player page's door. Thin on purpose — height, weight and the
    /// college fill in from the athlete fetch the page makes for any door
    /// that arrives without them.
    func identity(team: Team?) -> PlayerIdentity {
        PlayerIdentity(athleteId: athleteId,
                       name: name,
                       league: league,
                       teamName: team?.displayName ?? team?.location,
                       teamLogoURL: team?.logoURL,
                       team: team,
                       jersey: jersey,
                       position: position,
                       positionName: positionName,
                       headshotURL: headshotURL)
    }
}

/// The whole file. Every field optional — the ESPN rule applied to our own
/// file too, as `CoachStaffFile` does: a malformed row drops that player,
/// never the decode.
nonisolated struct ProAlumniFile: Sendable, Decodable {
    /// "2026-11-02" — moves only when a roster did, so newer-wins compares
    /// as strings.
    let updated: String?
    let colleges: [String: LossyArray<Entry>]?

    nonisolated struct Entry: Sendable, Decodable {
        /// `League.pathSegment`: "nfl", "nba", "nhl".
        let league: String?
        let athleteId: String?
        let name: String?
        let teamId: String?
        let position: String?
        let positionName: String?
        let jersey: String?
        let headshot: String?
    }

    /// The school's pros, in the file's order (league, then name). A row
    /// with no id, no name or a league the app doesn't cover is dropped —
    /// it would open an empty page.
    func alumni(collegeId: String) -> [ProAlumnus] {
        (colleges?[collegeId]?.elements ?? []).compactMap { entry in
            guard let slug = entry.league,
                  let league = League.allCases.first(where: { $0.pathSegment == slug }),
                  !league.isCollege,
                  let athleteId = entry.athleteId, !athleteId.isEmpty,
                  let name = entry.name, !name.isEmpty
            else { return nil }
            return ProAlumnus(league: league,
                              athleteId: athleteId,
                              name: name,
                              teamId: entry.teamId,
                              position: entry.position,
                              positionName: entry.positionName,
                              jersey: entry.jersey,
                              headshotURL: entry.headshot.flatMap(URL.init(string:)))
        }
    }
}
