import Foundation

/// A player's season-by-season numbers, as ESPN tables them.
///
/// **ESPN's categories and column labels are carried through, never named
/// here** — the box score's lesson (2026-09-05) without amendment. The
/// categories are per league and per position: a quarterback leads with
/// `passing`, a receiver with `receiving`, the NBA ships `averages` and
/// `totals`, and hockey splits `goaltender` from the skaters. ESPN orders a
/// player's categories by what they actually do, so the first one is the
/// player's own table — which is what the Current season card reads.
///
/// Every season the player has a line for is a row, with the club they
/// played it for. That *is* the Career tab: no aggregation, and ESPN's own
/// `totals` as the career line rather than a sum the app computed
/// (2026-09-24, answering E20's Career row).
nonisolated struct PlayerStats: Sendable, Hashable {
    struct Category: Sendable, Hashable, Identifiable {
        /// ESPN's machine name: "passing", "averages", "goaltender".
        let id: String
        /// ESPN's heading: "Passing", "Regular Season Averages".
        let title: String
        /// Column headers — "GP", "YDS", "TD".
        let labels: [String]
        /// Stable column keys — "gamesPlayed", "passingYards". What the
        /// headline registry matches on, so a relabelled column can't move
        /// which number the card shows.
        let names: [String]
        /// ESPN's full column names — "Passing Yards", "Points Per Game".
        /// Not its `descriptions[]`, which are glossary sentences ("The
        /// total passing yards.") and read like a textbook in a list.
        let displayNames: [String]
        /// Oldest first, as ESPN sends them.
        let seasons: [SeasonLine]
        /// ESPN's career line, positionally paired with `labels`. Empty when
        /// it doesn't match the header.
        let career: [String]
    }

    struct SeasonLine: Sendable, Hashable, Identifiable {
        /// ESPN's season year — the *ending* year for basketball and hockey.
        let year: Int
        /// "2026", "2025-26", "25-26" — whatever ESPN calls it.
        let label: String
        let teamId: String?
        /// The club's name, from the payload's own `teams` map.
        let teamName: String?
        let position: String?
        let values: [String]

        /// A player traded mid-season has two lines for one year.
        var id: String { "\(year)-\(teamId ?? "")" }
    }

    let categories: [Category]

    /// The categories with at least one season line — what the Stats and
    /// Career tabs draw. A category ESPN names with no rows would otherwise
    /// be a table of headers with nothing under them. The web's
    /// `categoriesWithLines` is the same rule.
    var categoriesWithLines: [Category] { categories.filter { !$0.seasons.isEmpty } }

    static let empty = PlayerStats(categories: [])
}

nonisolated extension PlayerStats.Category {
    /// The value in the column ESPN names `name`, for one line.
    func value(_ name: String, in values: [String]) -> String? {
        guard let index = names.firstIndex(of: name), values.indices.contains(index) else { return nil }
        let value = values[index]
        return value.isEmpty || value == "-" ? nil : value
    }

    /// The lines for one ESPN season year — usually one, two for a player
    /// traded mid-season.
    func lines(for year: Int) -> [PlayerStats.SeasonLine] {
        seasons.filter { $0.year == year }
    }
}

// MARK: - Headline numbers

nonisolated extension PlayerStats {
    /// One of the Current season card's numbers.
    struct Headline: Sendable, Hashable, Identifiable {
        let label: String
        let spokenLabel: String
        let value: String
        var id: String { label }
    }

    /// The Current season card's contents: games played, then the two or
    /// three numbers the player's own category is about — or nothing, which
    /// hides the card. A player with no line this season has no current
    /// season, and a column of zeroes would say otherwise.
    ///
    /// A traded player's lines for the year are not summed: the first line
    /// ESPN lists stands, because the app does not publish a figure it
    /// computed (E20's Career rule, applied here too).
    func headlines(forSeason year: Int) -> [Headline] {
        guard let category = categories.first,
              let line = category.lines(for: year).last else { return [] }
        let wanted = ["gamesPlayed", "games"] + Self.headlineNames(for: category)
        var seen: Set<String> = []
        return wanted.compactMap { name -> Headline? in
            guard let index = category.names.firstIndex(of: name),
                  let value = category.value(name, in: line.values),
                  seen.insert(category.labels[index]).inserted
            else { return nil }
            let spoken = category.displayNames.indices.contains(index)
                ? category.displayNames[index] : category.labels[index]
            return Headline(label: category.labels[index], spokenLabel: spoken, value: value)
        }
    }

    /// Which columns lead, keyed by ESPN's category name rather than by
    /// league — a receiver in either football league is the same question.
    /// A category this doesn't know shows its first three columns after
    /// games played, which is ESPN's own order of importance.
    static func headlineNames(for category: Category) -> [String] {
        switch category.id {
        case "passing": ["passingYards", "passingTouchdowns", "interceptions"]
        case "rushing": ["rushingYards", "rushingTouchdowns", "yardsPerRushAttempt"]
        case "receiving": ["receptions", "receivingYards", "receivingTouchdowns"]
        case "averages": ["avgPoints", "avgRebounds", "avgAssists"]
        case "goaltender": ["wins", "avgGoalsAgainst", "savePct"]
        case "center", "leftWing", "rightWing", "defense", "forward", "skater":
            ["goals", "assists", "points"]
        default:
            Array(category.names.filter { $0 != "gamesPlayed" && $0 != "games" }.prefix(3))
        }
    }
}

// MARK: - Game log

/// One season of a player's games, as ESPN logs them.
nonisolated struct PlayerGameLog: Sendable, Hashable {
    /// A run of columns that belong together — "Passing" over eleven,
    /// "Rushing" over five. Football's log is one flat row with repeated
    /// labels (two "YDS", two "TD"), and the groups are what tells them
    /// apart.
    struct ColumnGroup: Sendable, Hashable {
        let title: String
        let count: Int
    }

    struct Entry: Sendable, Hashable, Identifiable {
        let eventId: String
        let date: Date?
        /// Football only; ESPN sends none for basketball or hockey.
        let week: Int?
        /// True for "@", false for "vs".
        let isAway: Bool
        let opponentId: String?
        let opponentAbbreviation: String?
        let opponentName: String?
        let opponentLogoURL: URL?
        /// The player's own side that night — a traded player's log crosses
        /// clubs, so this is per game, not per page.
        let teamId: String?
        let teamAbbreviation: String?
        let teamLogoURL: URL?
        /// "W", "L", "T" — or nil for a game not yet decided.
        let result: String?
        let teamScore: String?
        let opponentScore: String?
        /// "West Semifinals - Game 4", "CFP Semifinal at the …".
        let note: String?
        /// Positionally paired with the log's `labels`.
        let values: [String]
        var id: String { eventId }
    }

    /// "2025-26 Regular Season", "2025-26 Postseason".
    struct Section: Sendable, Hashable, Identifiable {
        let title: String
        /// Newest first, the way ESPN lists them.
        let entries: [Entry]
        var id: String { title }
    }

    let labels: [String]
    let names: [String]
    let groups: [ColumnGroup]
    /// Newest season type first.
    let sections: [Section]
    /// The seasons ESPN will answer for, newest first — the season menu.
    let availableSeasons: [Int]
    /// The season this log is for.
    let season: Int?

    static let empty = PlayerGameLog(labels: [], names: [], groups: [], sections: [],
                                     availableSeasons: [], season: nil)

    var isEmpty: Bool { sections.allSatisfy(\.entries.isEmpty) }
}

nonisolated extension PlayerGameLog {
    /// The short line a game row prints — the same columns the Current
    /// season card leads with, looked up by name in this log's own header.
    func headline(for entry: Entry, category: String?) -> String {
        let picks: [String] = switch category {
        case "passing": ["passingYards", "passingTouchdowns", "interceptions"]
        case "rushing": ["rushingYards", "rushingTouchdowns"]
        case "receiving": ["receptions", "receivingYards", "receivingTouchdowns"]
        case "averages", "totals": ["points", "totalRebounds", "assists"]
        case "goaltender": ["saves", "savePct", "goalsAgainst"]
        case "center", "leftWing", "rightWing", "defense", "forward", "skater":
            ["goals", "assists", "points"]
        default: []
        }
        var parts: [String] = []
        for name in picks {
            guard let index = names.firstIndex(of: name),
                  entry.values.indices.contains(index), labels.indices.contains(index)
            else { continue }
            parts.append("\(entry.values[index]) \(labels[index])")
        }
        if parts.isEmpty {
            // Nothing named — the first three columns, which is ESPN's own
            // order of importance for this log.
            parts = zip(labels, entry.values).prefix(3).map { "\($1) \($0)" }
        }
        return parts.joined(separator: " · ")
    }
}
