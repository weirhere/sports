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

/// A conference's standings in ESPN's order — which encodes tiebreakers and
/// is not derivable from the records. Distinct from `ConferenceTeams` (the
/// alphabetical browse roster) on purpose: the two screens promise
/// different orders.
nonisolated struct ConferenceStandings: Identifiable, Hashable, Sendable {
    let id: Int?
    let name: String
    let entries: [ConferenceStanding]

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
                       followedIds: Set<Int>) -> [ConferenceStandings] {
        let (followed, rest) = list.reduce(into: ([ConferenceStandings](), [ConferenceStandings]())) {
            partition, conference in
            if conference.id.map(followedIds.contains) ?? false {
                partition.0.append(conference)
            } else {
                partition.1.append(conference)
            }
        }
        return followed + rest
    }
}
