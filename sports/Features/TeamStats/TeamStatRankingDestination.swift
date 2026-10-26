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
    let seasonLabel: String
}

/// A pushed player stat table, carrying its ranking like the team one.
struct PlayerStatRankingDestination: Hashable {
    let ranking: PlayerStatRanking
    let scopeName: String
    let seasonLabel: String
}
