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
    var followKey: String { "\(league.rawValue):\(id)" }

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
        case power4 = 0, group5, independent, fcs, nflConference, nflDivision, other

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

    /// The two NFL conferences, ids read live from
    /// `apis/v2/sports/football/nfl/standings` on 2026-09-05.
    private static let nflConferenceNames: [Int: String] = [
        8: "AFC",
        7: "NFC",
    ]

    /// The eight divisions, read live from the same endpoint at `level=3`,
    /// each mapped to its parent conference.
    private static let nflDivisionParents: [Int: Int] = [
        4: 8,   // AFC East
        12: 8,  // AFC North
        13: 8,  // AFC South
        6: 8,   // AFC West
        1: 7,   // NFC East
        10: 7,  // NFC North
        11: 7,  // NFC South
        3: 7,   // NFC West
    ]

    private static let nflDivisionNames: [Int: String] = [
        4: "AFC East",
        12: "AFC North",
        13: "AFC South",
        6: "AFC West",
        1: "NFC East",
        10: "NFC North",
        11: "NFC South",
        3: "NFC West",
    ]

    private static let nflNames: [Int: String] =
        nflConferenceNames.merging(nflDivisionNames) { conf, _ in conf }

    private static func names(in league: League) -> [Int: String] {
        switch league {
        case .collegeFootball: cfbNames
        case .nfl: nflNames
        }
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

    /// Only the two conference marks exist — `nfl/500/afc.png` and
    /// `nfl/500/nfc.png` (verified 200 on 2026-09-05). Divisions have no
    /// mark of their own and deliberately fall through to nil.
    private static let nflLogoSlugs: [Int: String] = [
        8: "afc",
        7: "nfc",
    ]

    private static func logoSlugs(in league: League) -> [Int: String] {
        switch league {
        case .collegeFootball: cfbLogoSlugs
        case .nfl: nflLogoSlugs
        }
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
        guard let id, let slug = logoSlugs(in: league)[id] else { return nil }
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
        switch league {
        case .nfl:
            return nflConferenceNames[id] != nil ? .nflConference : .nflDivision
        case .collegeFootball:
            if fcsNames[id] != nil { return .fcs }
            if power4.contains(id) { return .power4 }
            if id == 18 { return .independent }
            return .group5
        }
    }

    /// The conference an NFL division sits under, or nil for anything else.
    static func parent(of id: Int?, in league: League) -> Int? {
        guard league == .nfl, let id else { return nil }
        return nflDivisionParents[id]
    }

    /// An NFL conference's four divisions, in ESPN's East/North/South/West
    /// order. Empty for college football, which nests nothing.
    static func children(of id: Int?, in league: League) -> [Int] {
        guard league == .nfl, let id else { return [] }
        return nflDivisionParents
            .filter { $0.value == id }
            .keys
            .sorted { name(for: $0, in: .nfl) < name(for: $1, in: .nfl) }
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
    /// are its FBS conferences; the NFL's are the AFC and the NFC, in that
    /// order — the divisions hang beneath them rather than sitting in the
    /// same list.
    static func topLevelIds(in league: League) -> [Int] {
        switch league {
        case .collegeFootball: orderedIds
        case .nfl: [8, 7]
        }
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
