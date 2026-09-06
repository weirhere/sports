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

    /// The league's own mark — the one ESPN's own scoreboard declares for
    /// it, in `leagues[].logos[]`.
    ///
    /// The NFL's sits in the `leagues/` bucket beside the team marks;
    /// college football's does not, which is what the 2026-09-05 probe
    /// concluded from (`college-football`, `ncaa`, `ncaaf`, `cfb`,
    /// `ncaa_football` all 404 there). ESPN files it under `redesign/`
    /// instead, and ships it on every NCAAF scoreboard response — so both
    /// leagues wear a real badge and the name-only header rule that hole
    /// forced is retired (Andy, 2026-09-06).
    ///
    /// Static rather than decoded: the mark is a property of the league,
    /// not of a day's slate, so a header paints it on the first frame
    /// instead of after a fetch. A moved file degrades to the football
    /// glyph, exactly like an unknown conference id.
    ///
    /// Neither URL derives a dark twin — the NFL's payload does declare
    /// one, but a header badge rides `ConferenceLogo`'s light backing disc
    /// in dark mode, where a light-inked shield would vanish.
    var logoURL: URL? {
        switch self {
        case .nfl:
            URL(string: "https://a.espncdn.com/i/teamlogos/leagues/500/\(pathSegment).png")
        case .collegeFootball:
            URL(string: "https://a.espncdn.com/redesign/assets/img/icons/ESPN-icon-football-college.png")
        }
    }

    /// How far back the season picker goes. College football floors at the
    /// CFP era; the NFL keeps the same floor for consistency rather than
    /// offering decades nobody browses.
    var seasonFloor: Int { 2014 }

    /// The calendar month a season's first game can fall in. College
    /// football opens in August (Week 0's last weekend); the NFL opens in
    /// late July with the Hall of Fame Game, which an August floor cut off
    /// the front of the season entirely (Andy, 2026-09-06).
    var seasonOpensIn: Int {
        switch self {
        case .collegeFootball: 8
        case .nfl: 7
        }
    }

    /// The last calendar month that still belongs to the *previous* season.
    /// College football ends in January (bowls/CFP); the NFL runs through
    /// the February Super Bowl.
    var seasonRollsOverAfter: Int {
        switch self {
        case .collegeFootball: 1
        case .nfl: 2
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

    /// What a standings table calls its in-group record column — the
    /// conference record in both leagues.
    ///
    /// This said "DIV" for the NFL until 2026-09-05, on the belief that
    /// ESPN's NFL standings carried only a division record. They carry
    /// both, and the mapper has always read `vsconf`: the lookup beside it
    /// asked for `divisionRecord` where the payload spells the stat
    /// `divisionrecord`, so it never matched and every NFL table has been
    /// showing a conference record under a division caption. The caption
    /// moved to match the number rather than the other way around, because
    /// the league table (all 32 teams) has a conference record to show and
    /// no division one worth a column.
    static func inGroupRecordCaption(_ league: League) -> String { "CONF" }

    /// Whether the league ranks its teams. College football has the AP,
    /// Coaches and CFP polls; `/nfl/rankings` is a 404 and always will be.
    var hasPoll: Bool { self == .collegeFootball }

    /// The long form, for a card row rather than a table column.
    static func inGroupRecordLabel(_ league: League) -> String { "Conference" }

    /// The spoken form, for the row's VoiceOver sentence.
    static func inGroupRecordSpoken(_ league: League) -> String { "in conference" }

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
