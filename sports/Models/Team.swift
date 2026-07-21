import Foundation

nonisolated struct Team: Identifiable, Hashable, Sendable {
    let id: String
    let location: String          // "Georgia" — the row display name
    let name: String?             // "Bulldogs"
    let abbreviation: String?
    let displayName: String?      // "Georgia Bulldogs"
    let shortDisplayName: String?
    let logoURL: URL?
    let conferenceId: Int?
}

/// One FBS conference with its member teams, for the Teams browse screen.
nonisolated struct ConferenceTeams: Identifiable, Hashable, Sendable {
    let id: Int?
    let name: String
    let teams: [Team]
}

/// ESPN conference group ids, hardcoded with an "Other" fallback so an
/// unknown id degrades to a bucket, never a crash.
nonisolated enum Conference {
    enum Tier: Int, Comparable, Sendable {
        case power4 = 0, group5, independent, other

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static let fbsGroupId = 80

    private static let names: [Int: String] = [
        1: "ACC",
        151: "American",
        4: "Big 12",
        5: "Big Ten",
        12: "Conference USA",
        18: "Independents",
        15: "MAC",
        17: "Mountain West",
        9: "Pac-12",
        8: "SEC",
        37: "Sun Belt",
    ]

    private static let power4: Set<Int> = [1, 4, 5, 8]

    static func name(for id: Int?) -> String {
        guard let id, let name = names[id] else { return "Other" }
        return name
    }

    static func tier(for id: Int?) -> Tier {
        guard let id, names[id] != nil else { return .other }
        if power4.contains(id) { return .power4 }
        if id == 18 { return .independent }
        return .group5
    }
}
