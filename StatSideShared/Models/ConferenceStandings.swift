import Foundation

/// One team's line in a conference standings table. Records are ESPN's
/// summary strings ("7-1"); nil when the API omits the stat, which degrades
/// the row, never the table.
nonisolated struct ConferenceStanding: Identifiable, Hashable, Sendable {
    let team: Team
    let conferenceRecord: String?
    let overallRecord: String?
    let streak: String?
    /// ESPN's `playoffSeed` — the tiebreaker-aware standings position.
    /// 1-based when ESPN knows it; nil (or ESPN's 0) when it doesn't.
    var playoffSeed: Int? = nil
    /// ESPN's `winpercent`, 0...1 — its own number, ties already counted.
    /// The league table orders on it, and the NBA shows it as PCT. Absent
    /// from the NHL's payload entirely.
    var winPercent: Double? = nil
    /// Hockey's own three-number record, composed from wins, losses and
    /// overtime losses. ESPN's `total` summary is "53-22-7, 113 PTS" — a
    /// sentence, not a column.
    var winLossOTL: String? = nil
    var gamesPlayed: Int? = nil
    /// Standings points: two for a win, one for an overtime loss. What the
    /// NHL's tables are actually sorted by.
    var points: Int? = nil
    /// ESPN's own display string ("-", "3.5"), never computed here — the
    /// arithmetic is a tiebreaker's, and inventing one is what the
    /// standings contract forbids.
    var gamesBehind: String? = nil

    var id: String { team.id }
}

nonisolated extension Array where Element == ConferenceStandings {
    /// Folds a conference's division tables into one, for pages that ask
    /// for the conference and get its parts. Entry order is each division's
    /// in turn — the only order ESPN gives us, and inventing a cross-
    /// division ranking from records would be exactly the tiebreaker
    /// guesswork the standings contract forbids.
    func merged(as id: Int?, name: String, league: League) -> ConferenceStandings? {
        guard !isEmpty else { return nil }
        return ConferenceStandings(id: id, name: name,
                                   entries: flatMap(\.entries), league: league,
                                   spansDivisions: count > 1)
    }

    /// The whole league as one table: every top-level table's entries in
    /// one list, ranked by ESPN's win percentage.
    ///
    /// Built from the conference tables we already fetched rather than
    /// from `standings?level=1`, which costs a request to answer worse:
    /// its current-season order is this same win-percentage ranking, but
    /// its past-season order is a stale seed interleave that puts 14-2
    /// Baltimore ninth (probed live 2026-09-05).
    ///
    /// Ordering here doesn't breach the never-sort-standings rule — that
    /// rule protects orders that encode tiebreakers, and the NFL ranks
    /// nothing across its conferences. Win percentage is the only ordering
    /// a league table has, and it is exactly what ESPN's own league view
    /// shows. Ties keep the conference tables' order rather than inventing
    /// a winner between them.
    ///
    /// Nil unless every one of the league's top-level groups came back: a
    /// table calling itself the NFL with one conference missing would be
    /// a lie the row can't qualify.
    func leagueTable(in league: League) -> ConferenceStandings? {
        guard let id = Conference.leagueWideId(in: league) else { return nil }
        let tables = filter { $0.league == league && $0.parentId == nil }
        let present = Set(tables.compactMap(\.id))
        guard Set(Conference.topLevelIds(in: league)).isSubset(of: present) else { return nil }
        let entries = tables.flatMap(\.entries)
        guard !entries.isEmpty else { return nil }
        return ConferenceStandings(
            id: id, name: Conference.name(for: id, in: league),
            entries: entries.enumerated()
                .sorted { lhs, rhs in
                    let (l, r) = (Self.rank(lhs.element, in: league),
                                  Self.rank(rhs.element, in: league))
                    guard let l, let r, l != r else { return lhs.offset < rhs.offset }
                    return l > r
                }
                .map(\.element),
            league: league)
    }

    /// How a league table ranks rows it merged from its conferences: win
    /// percentage where the league keeps one, standings points where it
    /// keeps those instead.
    ///
    /// The NHL ships no `winpercent` at all, so every comparison fell to
    /// the source-order tiebreak and the "NHL" table came back East's
    /// seeds then West's — a table calling itself a ranking while ranking
    /// nothing. Points is what the NHL's own league view sorts on.
    private static func rank(_ entry: ConferenceStanding, in league: League) -> Double? {
        league == .nhl ? entry.points.map(Double.init) : entry.winPercent
    }

    /// The division tables a page shows at Division scope, out of every
    /// division its league has.
    ///
    /// Three different questions wearing one scope. A **league's** page
    /// shows them all. A **conference's** page shows the ones under it. A
    /// **division's** own page shows *itself* — it is one of these tables
    /// rather than a parent of them, and asking for its children finds
    /// nothing, which is how every division page said "Standings TBA"
    /// while the row that pushed it was teasing that division's leader.
    func divisionTables(for conference: ConferenceID,
                        isLeagueWide: Bool) -> [ConferenceStandings] {
        guard !isLeagueWide else { return self }
        if let own = first(where: { $0.conference == conference }) { return [own] }
        return filter { $0.parentId == conference.id && $0.league == conference.league }
    }

    /// One row per conference, divisions folded into their parent — the Sun
    /// Belt, not "Sun Belt - East" and "Sun Belt - West" — for lists that
    /// name conferences rather than table them. The standings themselves
    /// still keep each division's table: this is a display fold, and the
    /// folded row says so (`spansDivisions`), so nothing reads a division
    /// leader as the conference's.
    ///
    /// Divisions whose parent we can't name pass through unfolded: a merged
    /// row has to be able to say which conference it is.
    ///
    /// Re-sorts by the mappers' tier-then-name rule, which the fold can
    /// change — an unknown division id sorts last, its conference doesn't.
    /// A no-op for every table the fold left alone.
    func foldingDivisions() -> [ConferenceStandings] {
        var folded: [ConferenceStandings] = []
        var merged: Set<ConferenceID> = []
        for table in self {
            guard let parentId = table.parentId,
                  Conference.tier(for: parentId, in: table.league) != .other else {
                folded.append(table)
                continue
            }
            let parent = ConferenceID(table.league, parentId)
            guard merged.insert(parent).inserted else { continue }
            let divisions = filter { $0.parentId == parentId && $0.league == table.league }
            if let table = divisions.merged(as: parentId,
                                            name: Conference.name(for: parent),
                                            league: table.league) {
                folded.append(table)
            }
        }
        return folded.sorted { lhs, rhs in
            let (lt, rt) = (Conference.tier(for: lhs.id, in: lhs.league),
                            Conference.tier(for: rhs.id, in: rhs.league))
            return lt == rt ? lhs.name < rhs.name : lt < rt
        }
    }
}

/// A conference's standings in ESPN's order — which encodes tiebreakers and
/// is not derivable from the records. Distinct from `ConferenceTeams` (the
/// alphabetical browse roster) on purpose: the two screens promise
/// different orders.
nonisolated struct ConferenceStandings: Identifiable, Hashable, Sendable {
    let id: Int?
    let name: String
    let entries: [ConferenceStanding]
    /// Which league's group-id space `id` belongs to. Defaulted so the
    /// college-football call sites read unchanged.
    var league: League = .collegeFootball
    /// Set when this table is a division hanging under a conference — the
    /// 2019 AAC's East and West, or an NFL `level=3` request. The page for
    /// the parent conference collects these instead of finding nothing.
    var parentId: Int? = nil
    /// Set on a table merged from several divisions: its entry order is
    /// each division's in turn, so it ranks nothing across them.
    var spansDivisions: Bool = false

    /// The unambiguous identity — group id 8 is the SEC here and the AFC
    /// in the NFL.
    var conference: ConferenceID? { id.map { ConferenceID(league, $0) } }

    /// Whether this table belongs to `conference` — as the conference
    /// itself, or as one of its divisions.
    func belongs(to conference: ConferenceID) -> Bool {
        guard league == conference.league else { return false }
        return id == conference.id || parentId == conference.id
    }

    /// ESPN's placement stat beats payload order when it's complete:
    /// past-season responses come back sorted by overall record (found
    /// 2026-08-25 — 2024's payload listed Memphis over 7-1 Tulane), but
    /// every entry carries `playoffSeed`, the tiebreaker-aware standings
    /// position. A conference with missing or duplicated seeds (2024 MAC
    /// ships zeros) keeps payload order — imperfect but not invented.
    static func seedOrdered(_ entries: [ConferenceStanding]) -> [ConferenceStanding] {
        let seeds = entries.compactMap(\.playoffSeed)
        guard seeds.count == entries.count,
              seeds.allSatisfy({ $0 >= 1 }),
              Set(seeds).count == seeds.count else { return entries }
        return entries.sorted { ($0.playoffSeed ?? 0) < ($1.playoffSeed ?? 0) }
    }

    /// A division's own name inside its conference's page: ESPN ships
    /// "Sun Belt - East", and the hero one card above already said Sun
    /// Belt. Anything that doesn't start with the conference's name is
    /// left alone — a name we can't shorten honestly stays whole.
    func divisionName(under conferenceName: String) -> String {
        guard name.count > conferenceName.count,
              name.lowercased().hasPrefix(conferenceName.lowercased()) else { return name }
        let tail = name.dropFirst(conferenceName.count)
            .drop { $0 == " " || $0 == "-" || $0 == "\u{2013}" || $0 == ":" }
        return tail.isEmpty ? name : String(tail)
    }

    /// The top team, but only once the standings say something: a 0-0
    /// "leader" is last season's carried-over order, not information. A
    /// table merged from divisions has no top team at all — its first entry
    /// leads one division, and naming it the conference's leader would be
    /// the cross-division ranking the merge deliberately refuses to invent.
    var leader: ConferenceStanding? {
        guard !spansDivisions,
              let first = entries.first,
              // Asks the question rather than testing one league's field:
              // an NHL row has no conference record at all, so the old
              // `conferenceRecord != "0-0"` was nil there and every hockey
              // card would have hidden its leader forever.
              first.hasStartedInGroupPlay else { return nil }
        return first
    }

    /// Followed conferences pinned first (in the list's own relative order),
    /// the rest after. The input keeps its tier-then-name sort from the
    /// mappers; entries without an id can't be followed or pinned.
    static func pinned(_ list: [ConferenceStandings],
                       followedIds: Set<ConferenceID>) -> [ConferenceStandings] {
        let (followed, rest) = list.reduce(into: ([ConferenceStandings](), [ConferenceStandings]())) {
            partition, conference in
            if conference.conference.map(followedIds.contains) ?? false {
                partition.0.append(conference)
            } else {
                partition.1.append(conference)
            }
        }
        return followed + rest
    }
}
