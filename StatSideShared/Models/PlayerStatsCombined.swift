import Foundation

/// One club's seasons as one line — the Career tab's Teams view (Andy,
/// 2026-10-03: "it shouldn't be broken down by year, only by team").
///
/// This is the one place the app publishes a figure ESPN didn't, because
/// ESPN has no per-club split: the stats payload carries season lines and a
/// career line, and no filter or parameter turns up anything between
/// (probed the same day). So each column is rebuilt from what the rows
/// themselves say, by what ESPN's column *name* says it is, and a column
/// that can't be rebuilt honestly is a dash rather than a guess:
///
/// - a count (`passingYards`, `totalTackles`, `plusMinus`) is summed;
/// - a longest (`longPassing`) is the most;
/// - a rate with its parts on the row (`completionPct`,
///   `yardsPerPassAttempt`, `fieldGoalPct`) is recomputed from the summed
///   parts, never averaged;
/// - a per-game average (`avgPoints`, `timeOnIcePerGame`) is weighted by
///   games played — exact up to ESPN's own rounding of each season;
/// - anything else (`QBRating`, `adjQBR`, `production`) is "—".
///
/// A club with a single season is ESPN's row untouched.
nonisolated extension PlayerStats.Category {
    func combined(_ lines: [PlayerStats.SeasonLine]) -> [String] {
        guard lines.count > 1 else { return lines.first?.values ?? [] }
        let combiner = Combiner(names: names, lines: lines)
        return names.indices.map { combiner.value(at: $0) ?? "—" }
    }
}

private nonisolated struct Combiner {
    let names: [String]
    let lines: [PlayerStats.SeasonLine]

    /// Rates whose parts are both on the row: numerator, denominator,
    /// scale.
    private static let rates: [String: (String, String, Double)] = [
        "completionPct": ("completions", "passingAttempts", 100),
        "yardsPerPassAttempt": ("passingYards", "passingAttempts", 1),
        "yardsPerRushAttempt": ("rushingYards", "rushingAttempts", 1),
        "yardsPerReception": ("receivingYards", "receptions", 1),
        "avgInterceptionYards": ("interceptionYards", "interceptions", 1),
    ]

    /// Shooting percentages, by the made-attempted pair they come from.
    private static let shooting: [String: String] = [
        "fieldGoalPct": "fieldgoalsmade",
        "threePointFieldGoalPct": "threepointfieldgoalsmade",
        "freeThrowPct": "freethrowsmade",
    ]

    func value(at index: Int) -> String? {
        let name = names[index]
        let column = lines.map { $0.values.indices.contains(index) ? $0.values[index] : "" }
        let decimals = column.map(Self.decimals).max() ?? 0

        if let (numerator, denominator, scale) = Self.rates[name] {
            guard let top = sum(numerator), let bottom = sum(denominator) else { return nil }
            return bottom == 0 ? format(0, decimals: decimals) : format(top / bottom * scale, decimals: decimals)
        }
        if let stem = Self.shooting[name] {
            guard let pair = names.firstIndex(where: { Self.stem(of: $0) == stem }),
                  let parts = pairTotals(at: pair) else { return nil }
            return parts.1 == 0 ? format(0, decimals: decimals)
                : format(parts.0 / parts.1 * 100, decimals: decimals)
        }
        if name.contains("-") {
            guard let parts = pairTotals(at: index) else { return nil }
            if name.hasPrefix("avg") {
                guard let games = games() else { return nil }
                return "\(format(parts.0 / games, decimals: 1))-\(format(parts.1 / games, decimals: 1))"
            }
            return "\(format(parts.0, decimals: 0))-\(format(parts.1, decimals: 0))"
        }
        if name == "timeOnIcePerGame" {
            return weighted(column.map(Self.seconds)).map(Self.clock)
        }
        if name.hasPrefix("avg") {
            return weighted(column.map(Self.number)).map { format($0, decimals: decimals) }
        }
        let numbers = column.map(Self.number)
        guard decimals == 0, numbers.allSatisfy({ $0 != nil }) else { return nil }
        let values = numbers.compactMap { $0 }
        return format(name.hasPrefix("long") ? (values.max() ?? 0) : values.reduce(0, +), decimals: 0)
    }

    // MARK: - Totals

    /// A count column summed across the lines, or nil when any line's value
    /// isn't a whole number.
    private func sum(_ name: String) -> Double? {
        guard let index = names.firstIndex(of: name) else { return nil }
        let values = lines.map { $0.values.indices.contains(index) ? Self.number($0.values[index]) : nil }
        guard values.allSatisfy({ $0 != nil }) else { return nil }
        return values.compactMap { $0 }.reduce(0, +)
    }

    /// A made-attempted pair's two totals. A per-game pair ("7.9-18.9")
    /// is multiplied back out by each season's games first.
    private func pairTotals(at index: Int) -> (Double, Double)? {
        let perGame = names[index].hasPrefix("avg")
        var made = 0.0, attempted = 0.0
        for line in lines {
            guard line.values.indices.contains(index) else { return nil }
            let parts = line.values[index].split(separator: "-").map { Self.number(String($0)) }
            guard parts.count == 2, let m = parts[0], let a = parts[1] else { return nil }
            let scale = perGame ? (gamesPlayed(line) ?? .nan) : 1
            made += m * scale
            attempted += a * scale
        }
        return made.isNaN || attempted.isNaN ? nil : (made, attempted)
    }

    /// A per-game average across the lines, weighted by each one's games.
    private func weighted(_ values: [Double?]) -> Double? {
        var total = 0.0, games = 0.0
        for (line, value) in zip(lines, values) {
            guard let value, let played = gamesPlayed(line) else { return nil }
            total += value * played
            games += played
        }
        return games == 0 ? nil : total / games
    }

    private func games() -> Double? {
        let played = lines.map(gamesPlayed)
        guard played.allSatisfy({ $0 != nil }) else { return nil }
        let total = played.compactMap { $0 }.reduce(0, +)
        return total == 0 ? nil : total
    }

    private func gamesPlayed(_ line: PlayerStats.SeasonLine) -> Double? {
        guard let index = names.firstIndex(where: { $0 == "gamesPlayed" || $0 == "games" }),
              line.values.indices.contains(index) else { return nil }
        return Self.number(line.values[index])
    }

    // MARK: - Reading and writing ESPN's strings

    /// "1,915" → 1915, "-1" → -1; nil for "", "-", "18:53".
    private static func number(_ value: String) -> Double? {
        let cleaned = value.replacingOccurrences(of: ",", with: "")
        guard !cleaned.isEmpty, cleaned != "-", !cleaned.contains(":") else { return nil }
        return Double(cleaned)
    }

    private static func seconds(_ value: String) -> Double? {
        let parts = value.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    private static func clock(_ seconds: Double) -> String {
        let whole = Int(seconds.rounded())
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private static func decimals(_ value: String) -> Int {
        guard let dot = value.firstIndex(of: ".") else { return 0 }
        return value.distance(from: value.index(after: dot), to: value.endIndex)
    }

    /// "avgFieldGoalsMade-avgFieldGoalsAttempted" → "fieldgoalsmade".
    private static func stem(of name: String) -> String? {
        guard let made = name.split(separator: "-").first else { return nil }
        let lower = made.lowercased()
        return lower.hasPrefix("avg") ? String(lower.dropFirst(3)) : lower
    }

    /// Thousands grouped the way the table already writes them: football
    /// says "2,264", the NBA's totals say "1654".
    private var groupsThousands: Bool {
        !lines.contains { line in
            line.values.contains { value in
                value.count >= 4 && value.allSatisfy(\.isNumber)
            }
        }
    }

    private func format(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = groupsThousands
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }
}
