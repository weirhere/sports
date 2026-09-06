import Foundation

/// The shortlist the Add teams sheet offers before anyone types.
///
/// Curated, not measured, and deliberately so: the app has no analytics
/// (v1 has no backend at all) and ESPN publishes no popularity figure, so
/// there is nothing to derive this from. It is a hand-picked set of the
/// programs and franchises with the largest national followings, in
/// roughly that order — a starting point for someone who just installed
/// the app, not a ranking that claims to be anything else. Search is one
/// keystroke away for everyone else.
///
/// Ids are ESPN team ids, verified live against the standings payloads on
/// 2026-09-05. An id the directory doesn't carry is simply skipped, so a
/// realignment or a renamed franchise costs a row, never a crash.
nonisolated enum PopularTeams {
    /// One league's shortlist. A named type rather than a tuple because
    /// `ForEach` needs an identity and Swift has no key path into a tuple
    /// element.
    struct Group: Identifiable {
        let league: League
        let teams: [Team]

        var id: League { league }
    }

    private static let ids: [League: [String]] = [
        .collegeFootball: [
            "194",   // Ohio State
            "333",   // Alabama
            "61",    // Georgia
            "130",   // Michigan
            "251",   // Texas
            "87",    // Notre Dame
            "213",   // Penn State
            "99",    // LSU
            "2483",  // Oregon
            "30",    // USC
            "201",   // Oklahoma
            "228",   // Clemson
            "57",    // Florida
            "2633",  // Tennessee
            "158",   // Nebraska
        ],
        .nfl: [
            "6",     // Dallas Cowboys
            "12",    // Kansas City Chiefs
            "21",    // Philadelphia Eagles
            "25",    // San Francisco 49ers
            "9",     // Green Bay Packers
            "23",    // Pittsburgh Steelers
            "17",    // New England Patriots
            "2",     // Buffalo Bills
            "33",    // Baltimore Ravens
            "8",     // Detroit Lions
        ],
    ]

    /// The shortlist per league, in curated order, resolved against the
    /// loaded directory. A league whose teams haven't landed yet (the
    /// directory publishes college football first) is absent rather than
    /// present and empty.
    static func groups(in conferences: [ConferenceTeams]) -> [Group] {
        League.allCases.compactMap { league in
            let byId = Dictionary(
                conferences.filter { $0.league == league }.flatMap(\.teams).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let teams = (ids[league] ?? []).compactMap { byId[$0] }
            return teams.isEmpty ? nil : Group(league: league, teams: teams)
        }
    }
}
