import Foundation

/// Pure selection + refresh-policy rules for the widget, kept out of the
/// provider so sportsTests can exercise them without WidgetKit.
nonisolated enum GameSelection {
    /// The followed games worth showing, best-first: live games (soonest
    /// kickoff first), then upcoming games (soonest first), then the most
    /// recent final. Postponed/canceled games rank last.
    static func relevantGames(
        in games: [Game], followedIds: Set<String>, limit: Int, now: Date
    ) -> [Game] {
        guard !followedIds.isEmpty else { return [] }
        struct Ranked {
            let game: Game
            let priority: Int
            let order: TimeInterval
        }
        let followed = games.filter {
            followedIds.contains($0.home.team.id) || followedIds.contains($0.away.team.id)
        }
        let ranked = followed.map { game -> Ranked in
            let kickoff = game.date?.timeIntervalSince(now) ?? .greatestFiniteMagnitude
            switch game.status {
            case .live: return Ranked(game: game, priority: 0, order: kickoff)
            case .pre: return Ranked(game: game, priority: 1, order: kickoff)
            // Finals sort by recency: the game that ended last comes first.
            case .final: return Ranked(game: game, priority: 2, order: -kickoff)
            case .other: return Ranked(game: game, priority: 3, order: kickoff)
            }
        }
        let sorted = ranked.sorted { lhs, rhs in
            lhs.priority == rhs.priority ? lhs.order < rhs.order : lhs.priority < rhs.priority
        }
        return sorted.prefix(limit).map(\.game)
    }

    /// When the widget should ask for a new timeline. Sparse by design:
    /// WidgetKit's daily reload budget is the app's politeness throttle
    /// against ESPN, so a live game polls at 15 minutes, everything else
    /// hourly (pulled earlier if a kickoff lands sooner).
    static func nextRefresh(after now: Date, games: [Game]) -> Date {
        if games.contains(where: \.isLive) {
            return now.addingTimeInterval(15 * 60)
        }
        let upcoming = games
            .compactMap { game -> Date? in
                guard case .pre = game.status, let date = game.date, date > now else { return nil }
                return date
            }
            .min()
        let hourly = now.addingTimeInterval(60 * 60)
        guard let kickoff = upcoming else { return hourly }
        // Never schedule in the past-adjacent window; give kickoff a beat
        // so ESPN has flipped the game live by the time we refetch.
        let target = min(hourly, kickoff.addingTimeInterval(60))
        return max(target, now.addingTimeInterval(60))
    }
}
