import Foundation

/// The StatSide rating: college football's FBS teams ranked two-thirds on
/// résumé and one-third on performance (Andy, 2026-10-28, from his ranking
/// proposal). It replaces the record sort of 2026-10-25.
///
/// - **Résumé** is how unlikely a 90th-percentile FBS team would be to match
///   the record against the exact schedule.
/// - **Performance** is offense, defense and special teams from ESPN's
///   play-by-play, adjusted for the opponents faced.
///
/// Performance needs every game's play-by-play, about 800 summaries a
/// season, which is more than a phone should fetch. So the rating isn't
/// computed here. `scripts/statside-ranking.py` ranks the season off device
/// and publishes `statside-rating.json`, which the app bundles and
/// refreshes from statside.co (`StatSideRatingStore`). The method and its
/// backtest are in `docs/statside-ranking.md`.
nonisolated enum StatSideRating {
    /// How many make the headline tier. The rest are "Unranked".
    static let tierSize = 25

    /// The rule as one line, for the full list's footnote.
    static let rule = "Two-thirds résumé: how unlikely a 90th-percentile FBS team would be to match "
        + "this record against this schedule. One-third performance: offense, defense and special "
        + "teams from play-by-play, adjusted for opponents. Updated weekly from week 4."

    struct Row: Sendable, Hashable, Identifiable {
        let rank: Int
        let team: Team
        let wins: Int
        let losses: Int
        /// The combined score, 0–100.
        let score: Double
        let resumeRank: Int
        let performanceRank: Int

        var record: String { "\(wins)-\(losses)" }
        var scoreDisplay: String { score.formatted(.number.precision(.fractionLength(1))) }
        var isInTopTier: Bool { rank <= StatSideRating.tierSize }
        var id: String { team.id }
    }

    /// One season's list, and where it stands: "Week 9", or "Final" once
    /// the bowls are in.
    struct Season: Sendable, Hashable {
        let label: String
        let rows: [Row]
    }
}

/// `statside-rating.json`, as `scripts/statside-ranking.py --publish`
/// writes it: the seasons by year, each team with its identity and its
/// numbers. Every field is optional, which is the ESPN rule applied to our
/// own file too. An entry missing its id, place or record is dropped, and
/// never guessed.
nonisolated struct StatSideRatingFile: Sendable, Decodable {
    /// "2026-10-28". It moves only when a season's list did, so the newer
    /// file can be picked by comparing these as strings.
    let updated: String?
    let seasons: [String: SeasonEntry]?

    nonisolated struct SeasonEntry: Sendable, Decodable {
        let label: String?
        let throughWeek: Int?
        let teams: [TeamEntry]?
    }

    nonisolated struct TeamEntry: Sendable, Decodable {
        let id: String?
        let location: String?
        let name: String?
        let abbreviation: String?
        let displayName: String?
        let shortDisplayName: String?
        let logo: String?
        let conferenceId: Int?
        let rank: Int?
        let score: Double?
        let wins: Int?
        let losses: Int?
        let resumeRank: Int?
        let performanceRank: Int?
    }

    /// The list for one season, best first, or nil when the file has none.
    func season(_ year: Int) -> StatSideRating.Season? {
        guard let entry = seasons?[String(year)] else { return nil }
        let rows = (entry.teams ?? []).compactMap(Self.row).sorted { $0.rank < $1.rank }
        guard !rows.isEmpty else { return nil }
        return StatSideRating.Season(label: entry.label ?? "", rows: rows)
    }

    private static func row(_ entry: TeamEntry) -> StatSideRating.Row? {
        guard let id = entry.id, let location = entry.location, let rank = entry.rank,
              let wins = entry.wins, let losses = entry.losses else { return nil }
        let team = Team(id: id, location: location, name: entry.name, abbreviation: entry.abbreviation,
                        displayName: entry.displayName, shortDisplayName: entry.shortDisplayName,
                        logoURL: entry.logo.flatMap(URL.init(string:)), conferenceId: entry.conferenceId,
                        league: .collegeFootball)
        return StatSideRating.Row(rank: rank, team: team, wins: wins, losses: losses,
                                  score: entry.score ?? 0, resumeRank: entry.resumeRank ?? rank,
                                  performanceRank: entry.performanceRank ?? rank)
    }
}
