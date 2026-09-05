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
                                   entries: flatMap(\.entries), league: league)
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

    /// The top team, but only once the standings say something: a 0-0
    /// "leader" is last season's carried-over order, not information.
    var leader: ConferenceStanding? {
        guard let first = entries.first,
              let record = first.conferenceRecord, record != "0-0" else { return nil }
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
