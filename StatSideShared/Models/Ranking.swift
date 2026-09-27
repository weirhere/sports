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

/// One published edition of a season's polls: the preseason vote, a
/// regular-season week, or the final one after the bowls. ESPN's core API
/// files them as `types/{1|2|3}/weeks/{n}`, and those two numbers are the
/// whole address.
nonisolated struct PollWeek: Hashable, Comparable, Sendable {
    /// ESPN's season type: 1 preseason, 2 regular season, 3 postseason.
    let seasonType: Int
    let number: Int

    /// The menu's name for it. ESPN's own `occurrence.displayValue` says
    /// the same thing ("Week 4", "Final Rankings"), but only once the week
    /// is fetched — the menu has to name every week before any of them is.
    var label: String {
        switch seasonType {
        case 1: "Preseason"
        case 3: "Final"
        default: "Week \(number)"
        }
    }

    static func < (lhs: PollWeek, rhs: PollWeek) -> Bool {
        (lhs.seasonType, lhs.number) < (rhs.seasonType, rhs.number)
    }

    /// The week out of a `…/seasons/2025/types/2/weeks/7/rankings/1` ref.
    init?(ref: String) {
        let parts = ref.components(separatedBy: "/")
        guard let typeIndex = parts.firstIndex(of: "types"),
              let weekIndex = parts.firstIndex(of: "weeks"),
              typeIndex + 1 < parts.count, weekIndex + 1 < parts.count,
              let type = Int(parts[typeIndex + 1]),
              let week = Int(parts[weekIndex + 1].prefix { $0.isNumber })
        else { return nil }
        self.init(seasonType: type, number: week)
    }

    init(seasonType: Int, number: Int) {
        self.seasonType = seasonType
        self.number = number
    }
}
