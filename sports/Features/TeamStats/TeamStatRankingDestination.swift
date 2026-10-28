import Foundation

/// A pushed stat table. It carries the ranking it opens on, already
/// computed from the tab's one request, so the push costs nothing.
struct TeamStatRankingDestination: Hashable {
    let ranking: TeamStatRanking
    /// Whose table it is — "NFL", "SEC", "FBS" — for the subtitle.
    let scopeName: String
    let seasonLabel: String
}

/// The StatSide rating's whole table, pushed from its card.
struct StatSideRatingDestination: Hashable {
    let rows: [StatSideRating.Row]
    /// "2026 · Week 9": the season, then how far the published list runs.
    let seasonLabel: String

    init(rows: [StatSideRating.Row], seasonLabel: String) {
        self.rows = rows
        self.seasonLabel = seasonLabel
    }

    /// A season's published list under its league's season label, or nil
    /// when there is no list.
    init?(season: StatSideRating.Season?, league: League, year: Int) {
        guard let season, !season.rows.isEmpty else { return nil }
        self.rows = season.rows
        self.seasonLabel = [league.seasonLabel(year), season.label].filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// A pushed player stat table, carrying its ranking like the team one.
struct PlayerStatRankingDestination: Hashable {
    let ranking: PlayerStatRanking
    let scopeName: String
    let seasonLabel: String
}
