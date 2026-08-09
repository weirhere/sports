import Foundation

nonisolated struct Poll: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let shortName: String?
    let type: String?     // ESPN poll type: "ap", "usa", "cfp", …
    let headline: String?
    let ranks: [RankedTeam]
}

nonisolated struct RankedTeam: Identifiable, Hashable, Sendable {
    let team: Team
    let current: Int
    let previous: Int?
    let points: Double?
    let firstPlaceVotes: Int?
    let record: String?

    var id: String { team.id }

    /// Positive = moved up, negative = dropped, 0 = held, nil = new/unknown.
    var movement: Int? {
        guard let previous, previous > 0 else { return nil }
        return previous - current
    }
}
