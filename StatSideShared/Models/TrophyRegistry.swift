import Foundation

/// The closed history a trophy case can't derive: the seasons before
/// `League.seasonFloor`, which ESPN's season axis cannot reach at all.
///
/// A trophy count is a claim about history printed as a fact, so **only a
/// list checked against a citable source is ever read** (`verified`), and a
/// league with no list here is not broken: its case reports what the wire
/// says, captioned `since 2014` — correct, and never a wrong number. That
/// gate is `coveredKinds(in:)`.
///
/// ## What counts (decided 2026-11-04, COR-94)
///
/// 1. **College football's national title is the AP poll's champion for
///    1936–1997, then the title game** — the BCS game 1998–2013, the CFP
///    game from 2014, which the derived path already reads. One named source
///    per era and one winner per season, so a split year (1970, 1997) is the
///    AP's pick, nothing before 1936 counts, and USC's vacated 2004 BCS title
///    has no row. Because the count depends on that choice, the list carries
///    it as `source` and the card prints it.
/// 2. **Pre-Super-Bowl NFL championships count, as their own kind** — "NFL
///    Championship", 1920–1965 only, so a season never holds two titles.
/// 3. **Titles follow the franchise, not the name.** A franchise with no
///    successor (the original Senators, the Maroons) contributes nothing.
///
/// Every list speaks only for its own league, and no list carries conference
/// titles: those are always as old as the derivation.
///
/// ## Keying
///
/// By ESPN team id, and those are verifiable without a network: every id in
/// the pro leagues' `teamDivisions` maps was cross-checked against the
/// division it is filed under, and the captured fixtures carry an id, an
/// abbreviation and a display name for all 30 NBA teams, all 32 NHL teams and
/// 316 college football programs. An id that matches nothing contributes
/// nothing, so a bad row costs a missing trophy rather than a misplaced one.
nonisolated enum TrophyRegistry {
    /// One trophy's whole honour roll, as it is published: a list of
    /// seasons and who won each. Champion-list shaped rather than
    /// team-keyed because that is the form every source prints it in, and
    /// so an added row can be read straight down against one.
    struct TitleList: Sendable {
        let kind: TrophyKind
        /// Season year (the year the season *opens*, the app's own axis)
        /// → the winning team's ESPN id.
        let winners: [Int: String]
        /// Whether these rows have been checked against a source that can
        /// actually be cited. **Only a verified list is ever read**, so a
        /// half-entered honour roll can't reach a team page and print a
        /// count that is quietly short.
        let verified: Bool
        /// The selector behind the list, printed in the card's caption when
        /// the count depends on which one was chosen. Nil where the trophy is
        /// its own source (a Stanley Cup is won on the ice).
        var source: String? = nil
    }

    private static let lists: [League: [TitleList]] = [
        .collegeFootball: [collegeFootballNationalTitles],
    ]

    /// Every registry trophy this team holds.
    static func trophies(teamId: String, league: League) -> [Trophy] {
        (lists[league] ?? []).filter(\.verified).flatMap { list in
            list.winners
                .filter { $0.value == teamId }
                .map { Trophy(kind: list.kind, year: $0.key) }
        }
    }

    /// The trophies whose *whole* history this registry speaks for, by
    /// `TrophyKind.identity` — case-folded, so a list spelled one way and a
    /// derived row spelled another still meet.
    ///
    /// What makes a row's coverage caption honest. A league title in here
    /// is all-time; anything else — every conference title, always — is
    /// only as old as the derivation, because no registry list carries
    /// conference championships and none is planned to. There are eleven
    /// college football conferences against sixty years of realignment,
    /// and a conference table is the one part of this a season fetch
    /// already answers correctly.
    static func coveredKinds(in league: League) -> Set<String> {
        Set((lists[league] ?? []).filter(\.verified).map(\.kind.identity))
    }

    /// The selector each covered trophy is counted by, by
    /// `TrophyKind.identity`, for the card's caption. Only verified lists,
    /// like everything else read from here.
    static func sources(in league: League) -> [String: String] {
        var sources: [String: String] = [:]
        for list in (lists[league] ?? []) where list.verified {
            if let source = list.source { sources[list.kind.identity] = source }
        }
        return sources
    }
}
