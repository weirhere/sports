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

    /// What makes two trophies the same trophy, and it **folds case**.
    ///
    /// ESPN does not spell a headline the same way twice: the Rams' 2021
    /// season calls it "NFC Championship" and their 2018 season calls it
    /// "NFC CHAMPIONSHIP", which is two kinds under a synthesized
    /// `Hashable` and so two rows reading "1" where the shelf holds two of
    /// one thing (Andy, 2026-09-21). Since the name is taken from the wire
    /// by design — see `from(headline:league:)` — the wire's typography
    /// cannot be allowed to be identity.
    var identity: String { singular.lowercased() }

    /// Identity as a dictionary key. Spelled out rather than leaning on
    /// `Hashable`, because a `Dictionary` keeps the key it already holds
    /// when an equal one is assigned — which would hand the choice of
    /// letters to arrival order, and the derived seasons arrive in none.
    var key: String { "\(tier.rawValue)\u{0}\(identity)" }

    // Spelling is presentation, so it is deliberately out of both of
    // these; `preferredSpelling(_:_:)` is what decides which letters a
    // merged row actually prints. `plural` is out for the same reason: it
    // is derived from `singular` at the one place either is made.
    static func == (lhs: TrophyKind, rhs: TrophyKind) -> Bool {
        lhs.tier == rhs.tier && lhs.identity == rhs.identity
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(tier)
        hasher.combine(identity)
    }

    /// Which of two spellings of one trophy a row prints.
    ///
    /// Never a third spelling: both candidates are ESPN's own words, and
    /// the calmer one wins — counted, rather than an all-caps test, because
    /// the pair that needs deciding is often only half-shouted ("BIG TEN
    /// Championship" against "Big Ten Championship", once the common noun
    /// above has been fixed). A genuine tie breaks lexicographically, so a
    /// shelf can't reorder its own letters between launches.
    static func preferredSpelling(_ lhs: TrophyKind, _ rhs: TrophyKind) -> TrophyKind {
        let (left, right) = (lhs.singular.shoutiness, rhs.singular.shoutiness)
        if left != right { return left < right ? lhs : rhs }
        return lhs.singular <= rhs.singular ? lhs : rhs
    }
}

extension String {
    /// How loud a spelling is, for choosing between two of them.
    fileprivate var shoutiness: Int {
        reduce(0) { $0 + ($1.isUppercase ? 1 : 0) }
    }
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
        guard let printed = headline else { return nil }
        let headline = withoutSeriesGame(printed.trimmingCharacters(in: .whitespaces))
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
            // Named exactly, and checked before the conference round below
            // — both spell "Finals", and only one of them is the title.
            if text.contains("nba finals") {
                return TrophyKind(singular: "NBA Finals", plural: "NBA Finals", tier: .league)
            }
            // The in-season tournament is a real trophy; its group stage
            // and its earlier rounds are not. "NBA Cup - Group Play" and
            // "NBA Cup - Quarterfinals" are both confirmed headlines on
            // regular-season games, which is why this asks whether the
            // round *decided* anything rather than whether the string
            // mentions a final.
            // Its first edition (2023) was still the "In-Season Tournament"
            // on the wire — "NBA In-Season Tournament Championship", the
            // Lakers' (probed 2026-11-06) — and it is the same cup.
            if text.contains("nba cup") || text.contains("in-season tournament"),
               decidesATrophy(text) {
                return TrophyKind(singular: "NBA Cup", plural: "NBA Cups", tier: .league)
            }
            return conferenceFinals(text: text, league: .nba)
        case .nhl:
            // Same guard as the cup above, and for a documented reason: the
            // NHL called its earlier rounds "Stanley Cup Quarterfinals" and
            // "Stanley Cup Semifinals" for decades, so "mentions the cup
            // and a final" would hand a first-round exit the trophy.
            if text.contains("stanley cup"), decidesATrophy(text) {
                return TrophyKind(singular: "Stanley Cup", plural: "Stanley Cups", tier: .league)
            }
            return conferenceFinals(text: text, league: .nhl)
        case .mlb:
            // "World Series - Game 5" on every game of the series; the
            // champion is the last completed game's winner, as with the
            // NBA Finals. The pennants are the LCS's: "ALCS - Game 6".
            if text.hasPrefix("world series") {
                return TrophyKind(singular: "World Series", plural: "World Series", tier: .league)
            }
            if text.hasPrefix("alcs") {
                return TrophyKind(singular: "AL Pennant", plural: "AL Pennants", tier: .conference)
            }
            if text.hasPrefix("nlcs") {
                return TrophyKind(singular: "NL Pennant", plural: "NL Pennants", tier: .conference)
            }
            return nil
        case .wnba:
            // "WNBA Finals - Game 7"; the Commissioner's Cup is one game,
            // "WNBA Commissioner's Cup Championship" — its group games say
            // "WNBA Commissioner's Cup" alone and win nothing (June 2026).
            if text.hasPrefix("wnba finals") {
                return TrophyKind(singular: "WNBA Finals", plural: "WNBA Finals", tier: .league)
            }
            if text.contains("commissioner's cup championship") {
                return TrophyKind(singular: "Commissioner's Cup", plural: "Commissioner's Cups", tier: .league)
            }
            return nil
        case .mensCollegeBasketball, .womensCollegeBasketball:
            // The NCAA tournament's final only: "NIT - Championship" and
            // "College Basketball Crown Championship Game" decide trophies
            // too, but not the one a program counts.
            if text.hasPrefix("ncaa "), text.contains("national championship") {
                return TrophyKind(singular: "National Championship",
                                  plural: "National Championships", tier: .league)
            }
            return conferenceTournament(headline: headline, text: text)
        }
    }

    /// College basketball's conference tournament final: "SEC Tournament -
    /// Final", "Atlantic 10 Championship - Final", "America East Playoffs -
    /// Final", "Ivy League Tournament pres. by TIAA - Final" (live, March
    /// 2026). The trophy is the event's own name, kept as ESPN wrote it
    /// bar the round and a "pres. by" sponsor tail. The national
    /// postseason events (NCAA, NIT, WBIT, Crown) are never a conference's.
    private static func conferenceTournament(headline: String, text: String) -> TrophyKind? {
        let parts = headline.components(separatedBy: " - ")
        guard parts.count == 2,
              parts[1].trimmingCharacters(in: .whitespaces).lowercased() == "final" else { return nil }
        let event = text.components(separatedBy: " - ")[0]
        let national = ["ncaa ", "nit", "women's nit", "wbit", "college basketball crown"]
        guard !national.contains(where: { event.hasPrefix($0) }) else { return nil }
        var name = parts[0].trimmingCharacters(in: .whitespaces)
        if let sponsor = name.range(of: " pres. by ", options: .caseInsensitive) {
            name = String(name[..<sponsor.lowerBound])
        }
        guard !name.isEmpty else { return nil }
        return TrophyKind(singular: name, plural: name + "s", tier: .conference)
    }

    /// "SEC Championship", "AFC Championship" — the headline is already the
    /// trophy's name, so it is kept as written (bar a trailing "Game")
    /// rather than re-spelled from a conference registry. A conference we
    /// have never heard of still reads correctly, one that renames itself
    /// needs no code change, and a sponsor in the string is ESPN's own
    /// wording rather than ours to strip.
    ///
    /// Guarded on the word ending the headline, so "Championship Week" and
    /// a passing mention are both out. A trailing "Game" is tolerated
    /// because it is a coin-flip which way ESPN spells any given one — the
    /// captured SEC title game is plain "SEC Championship", and a league
    /// that writes "AFC Championship Game" must not silently win nothing.
    private static func conferenceChampionship(headline: String, text: String) -> TrophyKind? {
        var tail = text
        var name = headline.trimmingCharacters(in: .whitespaces)
        // The trophy is named after itself, not after the fixture: a team
        // holds three AFC Championships, it does not hold three AFC
        // Championship Games. Dropping the word also makes the name stable
        // whichever way ESPN spells a given league's title game.
        if tail.hasSuffix(" game") {
            tail = String(tail.dropLast(5))
            name = String(name.dropLast(5)).trimmingCharacters(in: .whitespaces)
        }
        guard tail.hasSuffix("championship"), tail != "championship" else { return nil }
        // One word is re-cased, and only one: ESPN shouts "NFC CHAMPIONSHIP"
        // in some seasons and writes "NFC Championship" in others, and a row
        // must not print a shout because of which season it was derived
        // from. The conference's own letters stay ESPN's, because re-casing
        // those would have to guess whether a token is an acronym ("SEC") or
        // a word ("Big Ten") — and on an all-caps string it would guess
        // wrong either way round. `identity` covers the prefix instead.
        let named = String(name.dropLast("championship".count)) + "Championship"
        return TrophyKind(singular: named, plural: named + "s", tier: .conference)
    }

    /// Whether a round name is the one that hands over a trophy.
    ///
    /// "Quarterfinals" and "Semifinals" both end in "final", which is the
    /// whole problem: a substring test for it promotes a team knocked out
    /// in the first round to champion. So a qualified round is ruled out by
    /// name, and what's left has to be the last word.
    private static func decidesATrophy(_ text: String) -> Bool {
        guard !text.contains("quarterfinal"), !text.contains("semifinal") else { return false }
        if text.contains("championship") { return true }
        return text.hasSuffix("final") || text.hasSuffix("finals")
    }

    /// The NBA's and NHL's conference round, under one name per league
    /// whatever the season called it.
    ///
    /// ESPN has spelled the round three ways (probed live 2026-11-06 across
    /// 2014–26): "Eastern Conference Finals" until 2017, "East Finals" from
    /// 2018, and in the NHL "East Final" from 2022. Kept as written, those
    /// are three trophies on one shelf — and before that, the "- Game N" on
    /// every game of the series made each game its own trophy, so a team
    /// that won Game 3 of a series it lost was credited with the title. So
    /// the round is matched whole, on the side alone, and named the league's
    /// way: the NBA's "Finals", the NHL's "Final". Matching the whole text is
    /// also what keeps the earlier rounds out — "East Semifinals" and
    /// "Eastern Conference First Round" don't qualify.
    private static func conferenceFinals(text: String, league: League) -> TrophyKind? {
        let sides = ["east": "Eastern", "eastern": "Eastern", "west": "Western", "western": "Western"]
        var words = text.split(separator: " ").map(String.init)
        guard words.count >= 2, let side = sides[words.removeFirst()] else { return nil }
        if words.first == "conference" { words.removeFirst() }
        guard words == ["final"] || words == ["finals"] else { return nil }
        let name = "\(side) Conference \(league == .nhl ? "Final" : "Finals")"
        return TrophyKind(singular: name, plural: name, tier: .conference)
    }

    /// A headline without the series game it names: "Stanley Cup Final -
    /// Game 7" is the Stanley Cup Final. Every game of a best-of-seven
    /// carries the same round with its own number, and the trophy is the
    /// round's — so the number comes off before anything is matched, which
    /// is what lets the games of one series share a key and the last
    /// completed one decide it. ESPN separates the two with a hyphen almost
    /// everywhere and an en dash at least once ("West Semifinals – Game 1",
    /// 2023).
    private static func withoutSeriesGame(_ headline: String) -> String {
        guard let range = headline.range(of: #"\s+[-–—]\s+game\s+\d+\s*$"#,
                                         options: [.regularExpression, .caseInsensitive])
        else { return headline }
        return String(headline[..<range.lowerBound])
    }
}

/// One row of the trophy case: a trophy, and the years this team won it.
nonisolated struct TrophyGroup: Identifiable, Hashable, Sendable {
    let kind: TrophyKind
    /// Newest first — a fan reads the most recent one as the headline.
    let years: [Int]
    let coverage: Coverage
    /// Which selector the count is by, when that is a choice the app made
    /// rather than a fact — "AP poll 1936–97 · title game since 1998" for
    /// college football's national titles. Printed in the card's caption,
    /// because a count that depends on a source has to name it.
    var source: String? = nil

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
        groups.compactMap { group -> Int? in
            guard case .since(let year) = group.coverage else { return nil }
            return year
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

        return byKind.compactMap { kind, games -> Trophy? in
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
                         allTimeKinds: Set<String>, derivedFloor: Int,
                         sources: [String: String] = [:]) -> TrophyCase {
        // Merged on identity, so a title both sources know about is one
        // row rather than two. The registry's window and the derivation's
        // are meant to abut rather than overlap, but a registry populated
        // past the floor is the normal end state of this feature, not an
        // error — so the overlap dedupes silently. Identity folds case, so
        // the spelling a merged row prints is chosen by rule as it goes
        // rather than left to whichever season happened to land first.
        var wins: [String: (kind: TrophyKind, years: Set<Int>)] = [:]
        for trophy in registry + derived {
            guard var entry = wins[trophy.kind.key] else {
                wins[trophy.kind.key] = (trophy.kind, [trophy.year])
                continue
            }
            entry.kind = TrophyKind.preferredSpelling(entry.kind, trophy.kind)
            entry.years.insert(trophy.year)
            wins[trophy.kind.key] = entry
        }

        let groups = wins.values.map { entry -> TrophyGroup in
            let years = entry.years.sorted(by: >)
            // All-time only where the registry says it speaks for this
            // trophy's whole history. Inferring it from the rows instead
            // would read "the oldest one we happen to know about" as "the
            // oldest one there is" — so a team whose only league title
            // came in the derived era would claim a complete shelf, which
            // is the omission this caption exists to prevent. Matched on
            // identity, like everything else here: a registry row and a
            // derived one must not miss each other over a capital.
            let coverage: TrophyGroup.Coverage = allTimeKinds.contains(entry.kind.identity)
                ? .allTime
                : .since(derivedFloor)
            // A source names what an all-time count is counted by, so it
            // rides only on a row the registry speaks for.
            let source = coverage == .allTime ? sources[entry.kind.identity] : nil
            return TrophyGroup(kind: entry.kind, years: years, coverage: coverage,
                               source: source)
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
