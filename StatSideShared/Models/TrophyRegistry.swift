import Foundation

/// The closed history a trophy case can't derive: the seasons before
/// `League.seasonFloor`, which ESPN's season axis cannot reach at all.
///
/// **This ships empty, deliberately, and the reason is the point.** The
/// mechanism is here, tested and gated; the rows are not, because a trophy
/// count is a claim about history printed as a fact, and every route to
/// verifying one was closed from the session that built this (ESPN, every
/// reference site and every encyclopedia are blocked by the egress policy;
/// only search summaries came through, truncated). Hand-transcribing a few
/// hundred rows of sports history out of snippets would have produced a
/// number no one could check — which is the failure this codebase keeps
/// catching late, and the one thing a shelf of trophies must never be.
///
/// A league with no rows here is not broken. Its case simply reports what
/// the wire says, captioned `since 2014` — correct, and never a wrong
/// number. That gate is `coveredKinds(in:)`.
///
/// ## Populating it
///
/// Three definitional calls have to be made first, and they are product
/// decisions rather than engineering ones — which is the other reason this
/// is empty. Each changes what a famous team's page claims:
///
/// 1. **Which selector is a college football national title?** Alabama's
///    case says 18 under its own claims, 13 under the AP, and 6 under
///    BCS-and-CFP-title-games-only. The polls split in plenty of seasons
///    (1997 was Michigan by the AP and Nebraska by the coaches; 1970 went
///    three ways), so "the champion" is not a fact the app can look up —
///    it is a source the app has to name. Whatever is chosen belongs in
///    `TrophyGroup.Coverage`'s caption so the page says it out loud.
/// 2. **Do pre-Super-Bowl NFL championships count?** The Packers won nine
///    of them. If they do, they need a trophy kind of their own — a
///    "Super Bowls" row must never absorb a title won before the game
///    existed, and naming the trophy is what makes that row self-scoping.
/// 3. **Where do a defunct franchise's titles go?** The original Ottawa
///    Senators won eleven Stanley Cups and the current Senators are a 1992
///    expansion team that has won none; the Montreal Maroons and Victoria
///    Cougars have no successor at all. Assigning those to a present-day
///    id by name is the wrong-number failure this gate exists to prevent.
///
/// ## Keying
///
/// By ESPN team id, and those are already verifiable without a network:
/// every id in the pro leagues' `teamDivisions` maps was cross-checked
/// against the division it is filed under, 32/32 for the NFL, and the
/// captured fixtures carry an id, an abbreviation and a display name for
/// all 30 NBA teams, all 32 NHL teams and 316 college football programs.
/// An id that matches nothing contributes nothing, so a bad row costs a
/// missing trophy rather than a misplaced one.
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
    }

    /// Empty until the three calls above are made and the rows are sourced.
    /// See BACKLOG E15.
    private static let lists: [League: [TitleList]] = [:]

    /// Every registry trophy this team holds.
    static func trophies(teamId: String, league: League) -> [Trophy] {
        (lists[league] ?? []).lazy.filter(\.verified).flatMap { list in
            list.winners
                .filter { $0.value == teamId }
                .map { Trophy(kind: list.kind, year: $0.key, gameId: nil) }
        }
    }

    /// The trophies whose *whole* history this registry speaks for, by
    /// `TrophyKind.singular`.
    ///
    /// What makes a row's coverage caption honest. A league title in here
    /// is all-time; anything else — every conference title, always — is
    /// only as old as the derivation, because no registry list carries
    /// conference championships and none is planned to. There are eleven
    /// college football conferences against sixty years of realignment,
    /// and a conference table is the one part of this a season fetch
    /// already answers correctly.
    static func coveredKinds(in league: League) -> Set<String> {
        Set((lists[league] ?? []).filter(\.verified).map(\.kind.singular))
    }
}
