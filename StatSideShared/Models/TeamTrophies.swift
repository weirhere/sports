import Foundation

/// What a team has won, and where each answer came from.
///
/// ESPN publishes **no team trophy list anywhere** — probed across the
/// payloads we hold on 2026-09-13, the only `awards` in any of them are a
/// link to espn.com's *player* awards page and a season-scoped athlete
/// `$ref`. Both are player honors: a Heisman, not a title.
///
/// What it does publish is the trophy *game*, by name. Every competition
/// carries `notes[].headline`, and Georgia's week-15 event reads exactly
/// "SEC Championship". So a title is one completed game with its name
/// printed on it, and the team's own result says who holds it.
///
/// That gives a trophy case two sources, and they cover different eras
/// (Andy's call, 2026-09-13 — the hybrid):
///
/// - **Derived**, from ESPN, for every season back to `League.seasonFloor`.
///   Nothing here is hand-maintained, so nothing here can go stale or be
///   silently dropped the year someone forgets to append a row.
/// - **`TrophyRegistry`**, hardcoded, for the closed history before that
///   floor — the seasons ESPN's season axis cannot reach at all.
///
/// They merge by `(kind, year)`, so a title both sources know about is one
/// row, not two. Each group then reports the span it can actually speak
/// for (`TrophyGroup.coverage`), because a case that quietly starts in 2014
/// is the lie-by-omission this app keeps refusing — Alabama has eighteen
/// national titles and a derived-only case would show six of them with no
/// hint that the number was partial.
nonisolated struct Trophy: Hashable, Sendable {
    let kind: TrophyKind
    /// The season it was won in, on the app's own axis — the year a season
    /// *opens*, which is what `League.espnSeason(for:)` translates at the
    /// query string and what a `SeasonMenuChip` renders.
    let year: Int
}

/// A trophy's identity, kept as both forms rather than pluralized by string
/// surgery — "NBA Finals" is already plural and "Stanley Cups" is not what
/// appending an s to "Stanley Cup Final" would give you.
nonisolated struct TrophyKind: Hashable, Sendable {
    /// What one of them is called: "Super Bowl", "SEC Championship".
    let singular: String
    /// What a shelf of them is called: "Super Bowls", "SEC Championships".
    let plural: String
    let tier: Tier

    /// Which shelf a trophy sits on. Ordering only — a league title leads,
    /// because it is the one a fan came to the tab to count.
    enum Tier: Int, Comparable, Sendable {
        case league = 0
        case conference = 1

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    func named(_ count: Int) -> String { count == 1 ? singular : plural }
}

extension TrophyKind {
    /// The trophy a game's printed headline names, or nil.
    ///
    /// Matched on ESPN's own wording and **silent on everything else**,
    /// which is the gate the whole feature rests on: branded kickoffs and
    /// neutral-site regular games live in this same field. "Aflac Kickoff",
    /// "Aer Lingus College Football Classic", "NFL Melbourne Game" and
    /// "NBA Cup - Group Play" are all real headlines on games that win
    /// nothing, so an unrecognized one contributes no row rather than a
    /// generic "Trophy" — `Postseason.collegeName`'s pattern exactly, which
    /// already reads a playoff round out of a sponsor-laden string and
    /// returns nil for a bowl.
    ///
    /// The league title is always checked first: "College Football Playoff
    /// National Championship" contains "championship", so a conference rule
    /// that ran first would claim it.
    static func from(headline: String?, league: League) -> TrophyKind? {
        guard let headline else { return nil }
        let text = headline.lowercased()
        guard !text.isEmpty else { return nil }

        switch league {
        case .collegeFootball:
            if text.contains("national championship") {
                return TrophyKind(singular: "National Championship",
                                  plural: "National Championships", tier: .league)
            }
            return conferenceChampionship(headline: headline, text: text)
        case .nfl:
            if text.contains("super bowl") {
                return TrophyKind(singular: "Super Bowl", plural: "Super Bowls", tier: .league)
            }
            return conferenceChampionship(headline: headline, text: text)
        case .nba:
            // Checked before the generic "finals" rule below, which would
            // otherwise swallow the conference finals into the league title.
            if text.contains("nba finals") {
                return TrophyKind(singular: "NBA Finals", plural: "NBA Finals", tier: .league)
            }
            // The in-season tournament is a real trophy, and its group
            // stage and quarterfinals are not — "NBA Cup - Group Play" is
            // the confirmed headline on four of one team's regular-season
            // games, so the cup only counts where it says it was decided.
            if text.contains("nba cup"),
               text.contains("championship") || text.contains("final") {
                return TrophyKind(singular: "NBA Cup", plural: "NBA Cups", tier: .league)
            }
            return conferenceFinals(headline: headline, text: text)
        case .nhl:
            if text.contains("stanley cup"), text.contains("final") {
                return TrophyKind(singular: "Stanley Cup", plural: "Stanley Cups", tier: .league)
            }
            return conferenceFinals(headline: headline, text: text)
        }
    }

    /// "SEC Championship", "AFC Championship" — the headline is already the
    /// trophy's name, so it is kept verbatim rather than re-spelled from a
    /// conference registry. A conference we have never heard of still reads
    /// correctly, and a conference that renames itself needs no code change.
    ///
    /// Guarded on the word standing alone at the end: "NBA Cup -
    /// Championship" and "Championship Week" are not conference titles, and
    /// a headline that merely mentions the word is not one either.
    private static func conferenceChampionship(headline: String, text: String) -> TrophyKind? {
        guard text.hasSuffix("championship"), text != "championship" else { return nil }
        let name = headline.trimmingCharacters(in: .whitespaces)
        return TrophyKind(singular: name, plural: name + "s", tier: .conference)
    }

    /// The NBA's and NHL's conference round: "Eastern Conference Finals".
    /// Already plural, like the NBA Finals it sits under.
    private static func conferenceFinals(headline: String, text: String) -> TrophyKind? {
        guard text.contains("conference final") else { return nil }
        let name = headline.trimmingCharacters(in: .whitespaces)
        return TrophyKind(singular: name, plural: name, tier: .conference)
    }
}

/// One row of the trophy case: a trophy, and the years this team won it.
nonisolated struct TrophyGroup: Identifiable, Hashable, Sendable {
    let kind: TrophyKind
    /// Newest first — a fan reads the most recent one as the headline.
    let years: [Int]
    let coverage: Coverage

    var id: String { kind.singular }
    var count: Int { years.count }
    var title: String { kind.named(count) }

    /// What the years behind a row can be trusted to cover.
    ///
    /// Printed, not hidden. A count is a claim about history, and the one
    /// thing worse than an incomplete shelf is an incomplete shelf that
    /// reads as a complete one.
    enum Coverage: Hashable, Sendable {
        /// The registry speaks for this trophy's whole history.
        case allTime
        /// Only the seasons ESPN's season axis reaches.
        case since(Int)

        var caption: String? {
            switch self {
            case .allTime: nil
            case .since(let year): "since \(year)"
            }
        }
    }
}

/// A team's shelf, assembled and ready to render.
nonisolated struct TrophyCase: Hashable, Sendable {
    /// League titles first, then conference titles; within a tier, the
    /// most-won trophy leads, and an equal count breaks on the most recent
    /// win so a live case reorders as titles land rather than alphabetically.
    let groups: [TrophyGroup]

    var isEmpty: Bool { groups.isEmpty }

    /// The narrowest span any row is limited to, or nil when every row is
    /// all-time. What the card's one footnote says, so the caption is
    /// stated once for the shelf instead of repeated on every row.
    var coverageFloor: Int? {
        groups.compactMap {
            if case .since(let year) = $0.coverage { year } else { nil }
        }.min()
    }
}

extension TrophyCase {
    /// Every trophy a team's own season shows it won.
    ///
    /// Two rules, both load-bearing:
    ///
    /// **A scheduled title game wins nothing.** Only a `final` game counts,
    /// so a conference championship a team is about to play contributes no
    /// row. The tab is what a team *has*; the Games tab is where a final
    /// they are yet to play belongs.
    ///
    /// **A series needs no series decoding.** The NBA's and NHL's finals are
    /// four to seven games all carrying one headline, and the champion is
    /// the winner of the chronologically **last completed** one — which is
    /// also the right answer for a single-game final, so one rule covers all
    /// four leagues. That is why this groups by kind before it looks at any
    /// result: taking every won game would credit a team that led a series
    /// 3-0 and lost it. It also leaves `competitions[].series` undecoded,
    /// which is the deferral the postseason bracket already made.
    static func derive(from schedule: TeamSchedule, league: League) -> [Trophy] {
        guard let teamId = schedule.team?.id, let year = schedule.year else { return [] }

        var byKind: [TrophyKind: [Game]] = [:]
        for game in schedule.games {
            guard let kind = TrophyKind.from(headline: game.headline, league: league),
                  game.home.team.id == teamId || game.away.team.id == teamId
            else { continue }
            byKind[kind, default: []].append(game)
        }

        return byKind.compactMap { kind, games in
            let decided = games
                .filter { if case .final = $0.status { true } else { false } }
                .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
            guard let clincher = decided.last,
                  let mine = [clincher.home, clincher.away]
                      .first(where: { $0.team.id == teamId }),
                  mine.winner == true
            else { return nil }
            return Trophy(kind: kind, year: year)
        }
    }

    /// The shelf, from every season the page has derived plus the registry's
    /// closed history.
    ///
    /// `derivedFloor` is the earliest season the derivation actually covers
    /// — the app's season floor once every season has loaded, and nothing is
    /// rendered before that point, since a half-loaded case would show a
    /// count that changes under the reader.
    static func assemble(derived: [Trophy], registry: [Trophy],
                         allTimeKinds: Set<String>, derivedFloor: Int) -> TrophyCase {
        // Merged on identity, so a title both sources know about is one
        // row rather than two. The registry's window and the derivation's
        // are meant to abut rather than overlap, but a registry populated
        // past the floor is the normal end state of this feature, not an
        // error — so the overlap dedupes silently.
        var wins: [TrophyKind: Set<Int>] = [:]
        for trophy in registry + derived {
            wins[trophy.kind, default: []].insert(trophy.year)
        }

        let groups = wins.map { kind, byYear -> TrophyGroup in
            let years = byYear.sorted(by: >)
            // All-time only where the registry says it speaks for this
            // trophy's whole history. Inferring it from the rows instead
            // would read "the oldest one we happen to know about" as "the
            // oldest one there is" — so a team whose only league title
            // came in the derived era would claim a complete shelf, which
            // is the omission this caption exists to prevent.
            let coverage: TrophyGroup.Coverage = allTimeKinds.contains(kind.singular)
                ? .allTime
                : .since(derivedFloor)
            return TrophyGroup(kind: kind, years: years, coverage: coverage)
        }

        return TrophyCase(groups: groups.sorted { lhs, rhs in
            if lhs.kind.tier != rhs.kind.tier { return lhs.kind.tier < rhs.kind.tier }
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            let (left, right) = (lhs.years.first ?? 0, rhs.years.first ?? 0)
            if left != right { return left > right }
            return lhs.kind.singular < rhs.kind.singular
        })
    }
}
