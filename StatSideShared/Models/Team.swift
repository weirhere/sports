import Foundation

nonisolated struct Team: Identifiable, Hashable, Sendable {
    let id: String
    let location: String          // "Georgia" — the row display name
    let name: String?             // "Bulldogs"
    let abbreviation: String?
    let displayName: String?
    let shortDisplayName: String?
    let logoURL: URL?
    let conferenceId: Int?
    /// Which league's id space `id` and `conferenceId` belong to. A `var`
    /// with a default rather than a `let`: Swift omits defaulted `let`
    /// properties from the memberwise init, and the mapper needs to pass a
    /// league in. Defaulted so the many college-football call sites read
    /// unchanged; the ESPN mapper always sets it from the client's own
    /// league, so a decoded team can never guess wrong.
    var league: League = .collegeFootball

    /// The unambiguous follow key. ESPN team ids collide across leagues —
    /// 26 is UCLA in college football and the Seahawks in the NFL — so the
    /// follow set stores this, never the bare id.
    var followKey: String { FollowKey(league: league, teamId: id).rawValue }

    /// This team's conference, qualified by league.
    var conference: ConferenceID? {
        conferenceId.map { ConferenceID(league, $0) }
    }
}

/// One conference with its member teams, for the Teams browse screen.
nonisolated struct ConferenceTeams: Identifiable, Hashable, Sendable {
    let id: Int?
    let name: String
    let teams: [Team]
    /// Which league's group-id space `id` belongs to. Defaulted so the
    /// college-football call sites read unchanged.
    var league: League = .collegeFootball

    /// The unambiguous identity — group id 8 is the SEC here and the AFC
    /// in the NFL.
    var conference: ConferenceID? { id.map { ConferenceID(league, $0) } }

    /// A `ForEach` identity that can't collide across leagues. `id` alone
    /// is the bare group id, so a list holding both the SEC and the AFC
    /// would hand SwiftUI two rows claiming to be number 8 — which corrupts
    /// the layout into blank card-sized gaps, the way duplicate ids did on
    /// the tables hub.
    var rowId: String { conference?.token ?? "other-\(name)" }
}

/// ESPN conference group ids, hardcoded per league with an "Other" fallback
/// so an unknown id degrades to a bucket, never a crash.
///
/// Every lookup takes a league because the id spaces overlap: 8 is the SEC
/// in college football and the AFC in the NFL; 1 is the ACC and the NFC
/// East; 4 is the Big 12 and the AFC East; 12 is Conference USA and the
/// AFC North.
nonisolated enum Conference {
    /// Browsing rank. `.fcs` sits below the FBS rungs rather than crossing
    /// them: an FCS conference has no P4/G5 meaning, but it does need a
    /// tier that isn't `.other`, because `.other` is the unknown-id bucket
    /// and callers use it to hide affordances (ConferencePage's Standings
    /// tab, the standings cut line). The NFL rungs work the same way —
    /// they exist so `.other` keeps meaning "unknown".
    enum Tier: Int, Comparable, Sendable {
        case power4 = 0, group5, independent, fcs
        /// A whole league standing as one table — the NFL's 32-team board.
        /// Above the conference rung so it leads its league's list: the
        /// league is what the conferences are parts of.
        case league
        /// A conference inside a league, and a division inside that — the
        /// AFC and the AFC East, the Eastern Conference and the Atlantic.
        /// Named for the rung rather than the league since the NBA and NHL
        /// nest exactly the same way (2026-09-08).
        case conference, division, other

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// College football's `groups=` parameter, which is also the division.
    /// Verified live 2026-09-01: group 81 returns 14 conferences / 116
    /// teams and ships the byte-identical week calendar as group 80, so the
    /// week strip needs no new model. The NFL has no analogue — its
    /// scoreboard takes no group filter at all.
    enum Division: Int, Sendable, CaseIterable {
        case fbs = 80, fcs = 81

        var groupId: Int { rawValue }
    }

    static let fbsGroupId = Division.fbs.groupId

    private static let fbsNames: [Int: String] = [
        1: "ACC",
        151: "American",
        4: "Big 12",
        5: "Big Ten",
        12: "Conference USA",
        18: "Independents",
        15: "MAC",
        17: "Mountain West",
        9: "Pac-12",
        8: "SEC",
        37: "Sun Belt",
    ]

    /// The 14 FCS conferences, ids read live from `standings?group=81`
    /// on 2026-09-01. Short forms match the FBS list's style (the browse
    /// row and section header carry them at row width), except "FCS
    /// Independents", which keeps its qualifier so it can't be read as
    /// id 18's FBS "Independents".
    private static let fcsNames: [Int: String] = [
        20: "Big Sky",
        48: "CAA",
        32: "FCS Independents",
        22: "Ivy League",
        24: "MEAC",
        21: "Missouri Valley",
        25: "Northeast",
        179: "Ohio Valley",
        27: "Patriot League",
        28: "Pioneer",
        29: "Southern",
        30: "Southland",
        31: "SWAC",
        177: "United Athletic",
    ]

    private static let cfbNames: [Int: String] = fbsNames.merging(fcsNames) { fbs, _ in fbs }

    /// One pro league's group hierarchy, hardcoded because the scoreboard
    /// payload carries none of it.
    ///
    /// ESPN's NFL, NBA and NHL scoreboards all ship team objects with no
    /// conference or group id at all, so without this every game of theirs
    /// falls into the "Other" bucket and a followed conference matches
    /// nothing. The precedent and the argument are the NFL's (2026-09-05):
    /// these leagues realign about once a decade, an id the table doesn't
    /// know still degrades to "Other", and a 30-row constant is the honest
    /// fix. College football needs none of it — its scoreboard ships the
    /// conference id inline.
    private struct Registry: Sendable {
        /// The group that stands for the whole league.
        let leagueWideId: Int
        let leagueName: String
        /// Ordered — this *is* `topLevelIds(in:)`.
        let conferences: [(id: Int, name: String)]
        let divisionNames: [Int: String]
        /// Division id → its conference id.
        let divisionParents: [Int: Int]
        /// Team id → its division id.
        let teamDivisions: [Int: Int]
        /// CDN slugs for the conference marks this league actually
        /// publishes. Empty where none exist.
        let conferenceSlugs: [Int: String]

        var allNames: [Int: String] {
            var names = divisionNames
            for conference in conferences { names[conference.id] = conference.name }
            names[leagueWideId] = leagueName
            return names
        }
    }

    /// Ids read live from `apis/v2/sports/football/nfl/standings` and the
    /// same endpoint at `level=3`, 2026-09-05.
    private static let nflRegistry = Registry(
        leagueWideId: 9,
        leagueName: "NFL",
        conferences: [(8, "AFC"), (7, "NFC")],
        divisionNames: [
            4: "AFC East", 12: "AFC North", 13: "AFC South", 6: "AFC West",
            1: "NFC East", 10: "NFC North", 11: "NFC South", 3: "NFC West",
        ],
        divisionParents: [4: 8, 12: 8, 13: 8, 6: 8, 1: 7, 10: 7, 11: 7, 3: 7],
        teamDivisions: [
            1: 11, 2: 4, 3: 10, 4: 12, 5: 12, 6: 1, 7: 6, 8: 10,
            9: 10, 10: 13, 11: 13, 12: 6, 13: 6, 14: 3, 15: 4, 16: 10,
            17: 4, 18: 11, 19: 1, 20: 4, 21: 1, 22: 3, 23: 12, 24: 6,
            25: 3, 26: 3, 27: 11, 28: 1, 29: 11, 30: 13, 33: 12, 34: 13,
        ],
        // `nfl/500/afc.png` and `nfl/500/nfc.png`, both verified 200 on
        // 2026-09-05. Divisions have no mark of their own.
        conferenceSlugs: [8: "afc", 7: "nfc"]
    )

    /// Ids read live from `apis/v2/sports/basketball/nba/standings` and the
    /// same endpoint at `level=3`, 2026-09-08.
    private static let nbaRegistry = Registry(
        leagueWideId: 7,
        leagueName: "NBA",
        conferences: [(5, "Eastern"), (6, "Western")],
        divisionNames: [
            1: "Atlantic", 2: "Central", 9: "Southeast",
            11: "Northwest", 4: "Pacific", 10: "Southwest",
        ],
        divisionParents: [1: 5, 2: 5, 9: 5, 11: 6, 4: 6, 10: 6],
        teamDivisions: [
            1: 9, 2: 1, 3: 10, 4: 2, 5: 2, 6: 10, 7: 11, 8: 2,
            9: 4, 10: 10, 11: 2, 12: 4, 13: 4, 14: 9, 15: 2, 16: 11,
            17: 1, 18: 1, 19: 9, 20: 1, 21: 4, 22: 11, 23: 4, 24: 10,
            25: 11, 26: 11, 27: 9, 28: 1, 29: 10, 30: 9,
        ],
        // ESPN publishes no NBA conference marks under any bucket
        // (`nba_conf` 404s, probed 2026-09-08); the rows wear the league
        // shield instead.
        conferenceSlugs: [:]
    )

    /// Ids read live from `apis/v2/sports/hockey/nhl/standings` and the
    /// same endpoint at `level=3`, 2026-09-08. The two long team ids are
    /// real: NHL team ids are not contiguous.
    private static let nhlRegistry = Registry(
        leagueWideId: 9,
        leagueName: "NHL",
        conferences: [(7, "Eastern"), (8, "Western")],
        divisionNames: [
            32: "Atlantic", 33: "Metropolitan",
            31: "Central", 30: "Pacific",
        ],
        divisionParents: [32: 7, 33: 7, 31: 8, 30: 8],
        teamDivisions: [
            1: 32, 2: 32, 3: 30, 4: 31, 5: 32, 6: 30, 7: 33, 8: 30,
            9: 31, 10: 32, 11: 33, 12: 33, 13: 33, 14: 32, 15: 33, 16: 33,
            17: 31, 18: 30, 19: 31, 20: 32, 21: 32, 22: 30, 23: 33, 25: 30,
            26: 32, 27: 31, 28: 31, 29: 33, 30: 31, 37: 30,
            124292: 30, 129764: 31,
        ],
        conferenceSlugs: [:]
    )

    /// The pro leagues, by league. College football is absent by design —
    /// its hierarchy comes off the wire.
    private static let registries: [League: Registry] = [
        .nfl: nflRegistry, .nba: nbaRegistry, .nhl: nhlRegistry,
    ]

    /// The group id standing for a whole league, where the league has one.
    ///
    /// College football has no counterpart: group 80 is FBS, its root ships
    /// no entries, and a 130-team table isn't a thing anyone reads — the
    /// poll answers "who's good" there.
    static func leagueWideId(in league: League) -> Int? {
        registries[league]?.leagueWideId
    }

    /// The division a pro team plays in, for payloads that carry no group
    /// of their own. Nil for college football, whose scoreboard ships the
    /// conference id inline.
    static func division(forTeamId id: String?, in league: League) -> Int? {
        guard let id, let numeric = Int(id) else { return nil }
        return registries[league]?.teamDivisions[numeric]
    }

    private static func names(in league: League) -> [Int: String] {
        league == .collegeFootball ? cfbNames : (registries[league]?.allNames ?? [:])
    }

    private static let power4: Set<Int> = [1, 4, 5, 8]

    /// ESPN CDN slugs, verified live against the /scoreboard/conferences
    /// endpoint on 2026-07-20. Hardcoded like the name tables: an unknown
    /// id just means no logo, never a broken image.
    private static let cfbLogoSlugs: [Int: String] = [
        1: "acc",
        151: "american",
        4: "big_12",
        5: "big_ten",
        12: "conference_usa",
        18: "fbs_independents",
        15: "mid_american",
        17: "mountain_west",
        9: "pac_12",
        8: "sec",
        37: "sun_belt",
        // FCS. All 13 verified 200 against the CDN on 2026-09-01;
        // United Athletic (177) has no mark under any plausible slug and
        // is deliberately absent, so `logoURL` returns nil for it rather
        // than a URL that 404s.
        20: "big_sky",
        48: "caa",
        32: "fcs_independents",
        22: "ivy",
        24: "meac",
        21: "missouri_valley",
        25: "northeast",
        179: "ovc",
        27: "patriot_league",
        28: "pioneer",
        29: "southern",
        30: "southland",
        31: "swac",
    ]

    private static func logoSlugs(in league: League) -> [Int: String] {
        league == .collegeFootball ? cfbLogoSlugs : (registries[league]?.conferenceSlugs ?? [:])
    }

    static func name(for id: Int?, in league: League) -> String {
        guard let id, let name = names(in: league)[id] else { return "Other" }
        return name
    }

    static func name(for conference: ConferenceID?) -> String {
        guard let conference else { return "Other" }
        return name(for: conference.id, in: conference.league)
    }

    /// CFBD identifies conferences by name, not id. Maps their names onto
    /// our ESPN group ids so tiers, ordering, and logos keep working when
    /// the CFBD backend is active. Unknown names degrade to nil ("Other").
    ///
    /// FBS-only, deliberately: `CFBDClient` asks every endpoint for
    /// `classification=fbs`, so an FCS conference name can never reach
    /// this table. CFBD is a college-football backend and has no NFL
    /// counterpart, so this needs no league parameter.
    private static let cfbdNames: [String: Int] = [
        "ACC": 1,
        "American Athletic": 151,
        "Big 12": 4,
        "Big Ten": 5,
        "Conference USA": 12,
        "FBS Independents": 18,
        "Mid-American": 15,
        "Mountain West": 17,
        "Pac-12": 9,
        "SEC": 8,
        "Sun Belt": 37,
    ]

    static func id(forCFBDName name: String?) -> Int? {
        guard let name else { return nil }
        return cfbdNames[name]
    }

    static func logoURL(for id: Int?, in league: League) -> URL? {
        // An NFL division has no mark of its own, so it wears its
        // conference's — an AFC East header showing the AFC shield reads
        // better than the generic fallback glyph.
        guard let id else { return nil }
        // The league's shield is filed under `leagues/`, not beside the
        // conference marks (`nfl/500/nfl.png` 404s — probed 2026-09-05).
        if id == leagueWideId(in: league) { return league.logoURL }
        guard let slug = logoSlugs(in: league)[id] else {
            // A division wears its conference's mark — an AFC East header
            // showing the AFC shield reads better than a bare glyph.
            if let parent = parent(of: id, in: league) {
                return logoURL(for: parent, in: league)
            }
            // A league that publishes *no* conference marks at all lets
            // its conferences wear its own shield: ESPN ships none for the
            // NBA or NHL under any bucket (probed 2026-09-08), so an
            // Eastern Conference row would otherwise fall to the football
            // glyph. A league that does publish them and is simply missing
            // one — FCS's United Athletic — still shows nothing, because
            // there the gap is about that conference, not the league.
            guard logoSlugs(in: league).isEmpty, isKnown(id, in: league) else { return nil }
            return league.logoURL
        }
        return URL(string:
            "https://a.espncdn.com/i/teamlogos/\(league.conferenceLogoPathComponent)/500/\(slug).png")
    }

    static func logoURL(for conference: ConferenceID?) -> URL? {
        guard let conference else { return nil }
        return logoURL(for: conference.id, in: conference.league)
    }

    /// Whether this league knows the id at all. The gate for affordances
    /// that only make sense over a real conference — the Standings tab,
    /// the standings cut line, conference follows.
    static func isKnown(_ id: Int?, in league: League) -> Bool {
        guard let id else { return false }
        return names(in: league)[id] != nil
    }

    /// Which college-football division a conference belongs to, or nil for
    /// an id the tables don't know. Always nil for the NFL, which has no
    /// division concept in this sense — use `isKnown` to ask whether an id
    /// is real.
    static func division(for id: Int?, in league: League) -> Division? {
        guard league == .collegeFootball, let id else { return nil }
        if fbsNames[id] != nil { return .fbs }
        return fcsNames[id] != nil ? .fcs : nil
    }

    static func tier(for id: Int?, in league: League) -> Tier {
        guard let id, names(in: league)[id] != nil else { return .other }
        guard let registry = registries[league] else {
            // College football: one flat list of conferences, ranked.
            if fcsNames[id] != nil { return .fcs }
            if power4.contains(id) { return .power4 }
            if id == 18 { return .independent }
            return .group5
        }
        if id == registry.leagueWideId { return .league }
        return registry.conferences.contains { $0.id == id } ? .conference : .division
    }

    /// Every group a team in `conference` belongs to, most specific first:
    /// its division, that division's conference, and the league itself.
    /// College football nests nothing, so its chain is the conference
    /// alone.
    ///
    /// This is what makes a conference follow match a game: a pro
    /// league's scoreboard gives a team its *division* id, so "I follow
    /// the AFC" — or the Eastern Conference — only means anything if the
    /// walk-up happens somewhere.
    static func chain(for conference: ConferenceID) -> [ConferenceID] {
        var chain = [conference]
        if let parent = parent(of: conference.id, in: conference.league) {
            chain.append(ConferenceID(conference.league, parent))
        }
        if let wide = leagueWideId(in: conference.league), wide != conference.id {
            chain.append(ConferenceID(conference.league, wide))
        }
        return chain
    }

    /// The conference a pro league's division sits under, or nil for
    /// anything else — college football nests nothing.
    static func parent(of id: Int?, in league: League) -> Int? {
        guard let id else { return nil }
        return registries[league]?.divisionParents[id]
    }

    /// A conference's divisions, alphabetically — the NFL's four East/
    /// North/South/West, the NBA's three, the NHL's two. Empty for college
    /// football, which nests nothing.
    static func children(of id: Int?, in league: League) -> [Int] {
        guard let id, let registry = registries[league] else { return [] }
        return registry.divisionParents
            .filter { $0.value == id }
            .keys
            .sorted { name(for: $0, in: league) < name(for: $1, in: league) }
    }

    /// Every known FBS conference in the app's browsing order: P4 → G5 →
    /// Independents, alphabetical within each tier. Deliberately still
    /// FBS-only — college football's default slate is FBS-shaped, and FCS
    /// is opt-in (E8 scope (b), Andy 2026-09-01). Callers that want the
    /// other division ask for it by name.
    static let orderedIds: [Int] = orderedIds(in: .fbs)

    /// One college-football division's conferences in browsing order. FCS
    /// has one tier, so its list is plainly alphabetical.
    static func orderedIds(in division: Division) -> [Int] {
        let table = division == .fbs ? fbsNames : fcsNames
        return table.keys.sorted { lhs, rhs in
            let (lt, rt) = (tier(for: lhs, in: .collegeFootball),
                            tier(for: rhs, in: .collegeFootball))
            return lt == rt
                ? name(for: lhs, in: .collegeFootball) < name(for: rhs, in: .collegeFootball)
                : lt < rt
        }
    }

    /// A league's top-level groups in browsing order. College football's
    /// are its FBS conferences; a pro league's are its conferences, in
    /// ESPN's own order — the divisions hang beneath them rather than
    /// sitting in the same list.
    static func topLevelIds(in league: League) -> [Int] {
        guard let registry = registries[league] else { return orderedIds }
        return registry.conferences.map(\.id)
    }

    /// Whether this conference's championship game takes the standings'
    /// top two that season — the gate for the standings cut line, which
    /// must never claim top-two about a divisional-era pairing. Every FBS
    /// conference has been one-table since 2024 except the Sun Belt (the
    /// divisional holdout, one-table from 2026); Independents have no
    /// title game at all.
    /// FBS only. FCS settles its title in a 24-team playoff and holds no
    /// conference championship games, and the NFL's postseason is a
    /// bracket, so the cut line must never claim top-two about either.
    static func titleGameIsTopTwo(id: Int?, year: Int, in league: League) -> Bool {
        guard league == .collegeFootball,
              let id, division(for: id, in: league) == .fbs, id != 18 else { return false }
        return year >= (id == 37 ? 2026 : 2024)
    }
}
