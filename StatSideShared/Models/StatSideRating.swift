import Foundation

/// The StatSide rating: college football's FBS teams ranked on results
/// alone (Andy's Performance Poll, 2026-10-25). No votes, no strength of
/// schedule, nothing a committee could argue with — fewest losses, then
/// most wins, then point differential, points scored, and fewest points
/// allowed.
///
/// Losses before wins is the rule doing its job: 7-1 and 6-0 have played
/// a different number of games, and the team that hasn't lost leads. Same
/// record means same games played, so the point totals behind it compare
/// like for like.
nonisolated enum StatSideRating {
    /// How many make the headline tier — the rest are "Unranked", the
    /// Notion view's two groups.
    static let tierSize = 25

    /// The rule as one line, for the full list's footnote.
    static let rule = "Fewest losses, then most wins, point differential, points for and fewest points against. No polls, no strength of schedule."

    struct Row: Sendable, Hashable, Identifiable {
        let rank: Int
        let team: Team
        let wins: Int
        let losses: Int
        let pointsFor: Int
        let pointsAgainst: Int

        var record: String { "\(wins)-\(losses)" }
        var differential: Int { pointsFor - pointsAgainst }
        var differentialDisplay: String {
            differential > 0 ? "+\(differential)" : "\(differential)"
        }
        var isInTopTier: Bool { rank <= StatSideRating.tierSize }
        var id: String { team.id }
    }

    /// The whole FBS table from a standings response. Teams are deduped by
    /// id — a divisional conference ships each team once per table it sits
    /// in — and FCS tables are left out, since the rating is FBS's. An
    /// entry missing any of the four numbers can't be placed and is
    /// dropped rather than guessed. A season nobody has played yet answers
    /// empty.
    static func ranking(from standings: [ConferenceStandings]) -> [Row] {
        var seen: Set<String> = []
        var lines: [(team: Team, wins: Int, losses: Int, pf: Int, pa: Int)] = []
        for table in standings where table.league == .collegeFootball
            && Conference.division(for: table.id, in: .collegeFootball) != .fcs {
            for entry in table.entries where seen.insert(entry.team.id).inserted {
                let record = entry.overallRecord.flatMap(winsAndLosses)
                guard let wins = entry.wins ?? record?.wins,
                      let losses = entry.losses ?? record?.losses,
                      let pf = entry.pointsFor, let pa = entry.pointsAgainst else { continue }
                lines.append((entry.team, wins, losses, pf, pa))
            }
        }
        guard lines.contains(where: { $0.wins + $0.losses > 0 }) else { return [] }
        let sorted = lines.sorted { lhs, rhs in
            if lhs.losses != rhs.losses { return lhs.losses < rhs.losses }
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            let lhsDiff = lhs.pf - lhs.pa, rhsDiff = rhs.pf - rhs.pa
            if lhsDiff != rhsDiff { return lhsDiff > rhsDiff }
            if lhs.pf != rhs.pf { return lhs.pf > rhs.pf }
            if lhs.pa != rhs.pa { return lhs.pa < rhs.pa }
            return lhs.team.location < rhs.team.location
        }
        return sorted.enumerated().map { index, line in
            Row(rank: index + 1, team: line.team, wins: line.wins, losses: line.losses,
                pointsFor: line.pf, pointsAgainst: line.pa)
        }
    }

    /// "7-1" or "7-1-1" → (7, 1). ESPN's college football standings ship
    /// `wins` but no `losses` stat at all — none of the 138 FBS teams on
    /// 2026-10-26 — so the loss count, the rating's first key, lives only
    /// in the overall record's summary.
    static func winsAndLosses(_ record: String) -> (wins: Int, losses: Int)? {
        let parts = record.split(separator: "-").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 2, let wins = parts[0], let losses = parts[1] else { return nil }
        return (wins, losses)
    }
}
