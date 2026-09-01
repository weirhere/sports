import Foundation

nonisolated struct Team: Identifiable, Hashable, Sendable {
    let id: String
    let location: String          // "Georgia" — the row display name
    let name: String?             // "Bulldogs"
    let abbreviation: String?
    let displayName: String?      // "Georgia Bulldogs"
    let shortDisplayName: String?
    let logoURL: URL?
    let conferenceId: Int?
}

/// One FBS conference with its member teams, for the Teams browse screen.
nonisolated struct ConferenceTeams: Identifiable, Hashable, Sendable {
    let id: Int?
    let name: String
    let teams: [Team]
}

/// ESPN conference group ids, hardcoded with an "Other" fallback so an
/// unknown id degrades to a bucket, never a crash.
nonisolated enum Conference {
    /// Browsing rank. `.fcs` sits below the FBS rungs rather than crossing
    /// them: an FCS conference has no P4/G5 meaning, but it does need a
    /// tier that isn't `.other`, because `.other` is the unknown-id bucket
    /// and callers use it to hide affordances (ConferencePage's Standings
    /// tab, the standings cut line).
    enum Tier: Int, Comparable, Sendable {
        case power4 = 0, group5, independent, fcs, other

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// ESPN's `groups=` parameter, which is also the division. Verified
    /// live 2026-09-01: group 81 returns 14 conferences / 116 teams and
    /// ships the byte-identical week calendar as group 80, so the week
    /// strip needs no new model.
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

    private static let names: [Int: String] = fbsNames.merging(fcsNames) { fbs, _ in fbs }

    private static let power4: Set<Int> = [1, 4, 5, 8]

    /// ESPN CDN slugs, verified live against the /scoreboard/conferences
    /// endpoint on 2026-07-20. Hardcoded like `names`: an unknown id just
    /// means no logo, never a broken image.
    private static let logoSlugs: [Int: String] = [
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

    static func name(for id: Int?) -> String {
        guard let id, let name = names[id] else { return "Other" }
        return name
    }

    /// CFBD identifies conferences by name, not id. Maps their names onto
    /// our ESPN group ids so tiers, ordering, and logos keep working when
    /// the CFBD backend is active. Unknown names degrade to nil ("Other").
    ///
    /// FBS-only, deliberately: `CFBDClient` asks every endpoint for
    /// `classification=fbs`, so an FCS conference name can never reach
    /// this table. CFBD parity for FCS would start at the client, not
    /// here (E8).
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

    static func logoURL(for id: Int?) -> URL? {
        guard let id, let slug = logoSlugs[id] else { return nil }
        return URL(string: "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/\(slug).png")
    }

    /// Which division a conference belongs to, or nil for an id neither
    /// table knows.
    static func division(for id: Int?) -> Division? {
        guard let id else { return nil }
        if fbsNames[id] != nil { return .fbs }
        return fcsNames[id] != nil ? .fcs : nil
    }

    static func tier(for id: Int?) -> Tier {
        guard let id, names[id] != nil else { return .other }
        if fcsNames[id] != nil { return .fcs }
        if power4.contains(id) { return .power4 }
        if id == 18 { return .independent }
        return .group5
    }

    /// Every known FBS conference in the app's browsing order: P4 → G5 →
    /// Independents, alphabetical within each tier. Deliberately still
    /// FBS-only — the app's default slate is FBS-shaped, and FCS is
    /// opt-in (E8 scope (b), Andy 2026-09-01). Callers that want the
    /// other division ask for it by name.
    static let orderedIds: [Int] = orderedIds(in: .fbs)

    /// One division's conferences in browsing order. FCS has one tier, so
    /// its list is plainly alphabetical.
    static func orderedIds(in division: Division) -> [Int] {
        let table = division == .fbs ? fbsNames : fcsNames
        return table.keys.sorted { lhs, rhs in
            let (lt, rt) = (tier(for: lhs), tier(for: rhs))
            return lt == rt ? name(for: lhs) < name(for: rhs) : lt < rt
        }
    }

    /// Whether this conference's championship game takes the standings'
    /// top two that season — the gate for the standings cut line, which
    /// must never claim top-two about a divisional-era pairing. Every FBS
    /// conference has been one-table since 2024 except the Sun Belt (the
    /// divisional holdout, one-table from 2026); Independents have no
    /// title game at all.
    /// FBS only. FCS settles its title in a 24-team playoff and holds no
    /// conference championship games, so the cut line must never claim
    /// top-two about one — and `names` now answers for both divisions,
    /// which is exactly what would have let an FCS id through.
    static func titleGameIsTopTwo(id: Int?, year: Int) -> Bool {
        guard let id, division(for: id) == .fbs, id != 18 else { return false }
        return year >= (id == 37 ? 2026 : 2024)
    }
}
