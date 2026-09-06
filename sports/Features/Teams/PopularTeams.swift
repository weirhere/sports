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

    /// The shortlist as one list, resolved against the loaded directory.
    ///
    /// Interleaved rather than league after league (Andy, 2026-09-06, when
    /// the sheet dropped its league headings): a flat concatenation is a
    /// grouping whether or not anything says so, and it would put every
    /// college program above every franchise — fifteen cards of scrolling
    /// before an NFL fan sees a team they recognise. Round-robin by
    /// position instead, so the top of the sheet is both leagues' biggest
    /// names and each league keeps its own curated order within the mix.
    ///
    /// A league whose teams haven't landed yet (the directory publishes
    /// college football first) simply contributes nothing.
    static func teams(in conferences: [ConferenceTeams]) -> [Team] {
        let perLeague = League.allCases.map { league -> [Team] in
            let byId = Dictionary(
                conferences.filter { $0.league == league }.flatMap(\.teams).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            return (ids[league] ?? []).compactMap { byId[$0] }
        }
        // Proportional round-robin: each league is drawn from at a rate set
        // by its own length, so a 15-team list and a 10-team one finish
        // together instead of the shorter one running out a third of the
        // way down.
        let longest = perLeague.map(\.count).max() ?? 0
        guard longest > 0 else { return [] }
        var merged: [Team] = []
        for step in 0..<longest {
            for league in perLeague where !league.isEmpty {
                let position = step * league.count / longest
                let previous = step == 0 ? -1 : (step - 1) * league.count / longest
                if position != previous { merged.append(league[position]) }
            }
        }
        return merged
    }
}
