import Foundation

/// The leagues StatSide covers. Every ESPN request, every id namespace, and
/// every time-model rule hangs off this — ESPN's team and conference id
/// spaces are per-league and they collide hard (20 of 32 NFL team ids are
/// also real CFB teams: UCLA/Seahawks, Stanford/Chargers, USC/Jaguars; and
/// conference id 8 is the SEC in college football, the AFC in the NFL).
///
/// The raw value is the persistence token. It is written into follow keys,
/// filter tokens, widget snapshots and deep links, so it must never change.
nonisolated enum League: String, Sendable, Codable, CaseIterable, Identifiable, Hashable {
    case collegeFootball = "cfb"
    case nfl

    var id: String { rawValue }

    /// The sport path segment in ESPN's URL. The only thing separating the
    /// two leagues' endpoints — verified live 2026-09-05: scoreboard,
    /// standings, summary, and team-schedule responses are shape-identical.
    var pathSegment: String {
        switch self {
        case .collegeFootball: "college-football"
        case .nfl: "nfl"
        }
    }

    /// Row- and chip-width name.
    var shortName: String {
        switch self {
        case .collegeFootball: "CFB"
        case .nfl: "NFL"
        }
    }

    var displayName: String {
        switch self {
        case .collegeFootball: "College Football"
        case .nfl: "NFL"
        }
    }

    /// The league's own mark, for the selector and cross-league rows.
    var logoURL: URL? {
        URL(string: "https://a.espncdn.com/i/teamlogos/leagues/500/\(pathSegment).png")
    }

    /// How far back the season picker goes. College football floors at the
    /// CFP era; the NFL keeps the same floor for consistency rather than
    /// offering decades nobody browses.
    var seasonFloor: Int { 2014 }

    /// The last calendar month that still belongs to the *previous* season.
    /// College football ends in January (bowls/CFP); the NFL runs through
    /// the February Super Bowl.
    var seasonRollsOverAfter: Int {
        switch self {
        case .collegeFootball: 1
        case .nfl: 2
        }
    }

    /// Weekdays (`Calendar` numbering, 1 = Sunday) on which the week strip
    /// stays pinned to the week that just finished rather than following
    /// ESPN's flipped-forward current week.
    ///
    /// College football's slate is Saturday, so Sunday is catch-up day and
    /// the new poll drops in place. The NFL's week runs Thursday → Monday,
    /// so Monday night is still *this* week and Tuesday is the dead day —
    /// both pin back, and the strip rolls over Wednesday morning.
    var completedWeekWeekdays: Set<Int> {
        switch self {
        case .collegeFootball: [1]        // Sunday
        case .nfl: [2, 3]                 // Monday, Tuesday
        }
    }

    /// The path component ESPN files this league's team marks under, e.g.
    /// `/i/teamlogos/ncaa/500/130.png` vs `/i/teamlogos/nfl/500/sea.png`.
    /// Both publish a `500-dark` twin (NFL verified live 2026-09-05).
    var teamLogoPathComponent: String {
        switch self {
        case .collegeFootball: "ncaa"
        case .nfl: "nfl"
        }
    }

    /// Where conference marks live. College football has its own
    /// `ncaa_conf` bucket; the NFL files AFC/NFC beside the team marks
    /// (`nfl_conf` 404s — probed live 2026-09-05).
    var conferenceLogoPathComponent: String {
        switch self {
        case .collegeFootball: "ncaa_conf"
        case .nfl: "nfl"
        }
    }
}

/// A conference identified unambiguously across leagues.
///
/// A bare `Int` is the bug: ESPN group id 8 is the SEC in college football
/// and the American Football Conference in the NFL, and ids 1, 4, 12 collide
/// the same way. Anything persisted, navigated to, or looked up in a name
/// table carries the league with it.
nonisolated struct ConferenceID: Hashable, Codable, Sendable, Identifiable {
    let league: League
    let id: Int

    init(_ league: League, _ id: Int) {
        self.league = league
        self.id = id
    }

    /// Convenience for the common college-football case.
    static func cfb(_ id: Int) -> ConferenceID { ConferenceID(.collegeFootball, id) }
    static func nfl(_ id: Int) -> ConferenceID { ConferenceID(.nfl, id) }

    /// The persistence token: `"cfb-8"`. Round-trips through
    /// `init?(token:)`, which accepts a bare `"8"` as college football so
    /// values written before the league axis existed still read back.
    var token: String { "\(league.rawValue)-\(id)" }

    init?(token: String) {
        if let id = Int(token) {
            self = ConferenceID(.collegeFootball, id)
            return
        }
        let parts = token.split(separator: "-", maxSplits: 1)
        guard parts.count == 2,
              let league = League(rawValue: String(parts[0])),
              let id = Int(parts[1]) else { return nil }
        self = ConferenceID(league, id)
    }
}
