import Foundation

/// Pure selection + refresh-policy rules for the widget, kept out of the
/// provider so sportsTests can exercise them without WidgetKit.
nonisolated enum GameSelection {
    /// How long a finished game keeps its slot past the day it was played
    /// in. A late kickoff files under the day it started, so "is it still
    /// today" alone would clear a 10:30pm game the instant it went final;
    /// six hours outlasts any football game, overtime included.
    static let overnightGrace: TimeInterval = 6 * 3600

    /// Yesterday through a fortnight out — a day range, not ESPN's current
    /// week, because a week is only ever the *asking* league's week. On the
    /// Sunday after a Saturday slate ESPN has rolled the NFL forward to
    /// next weekend while college football's week still holds yesterday's
    /// finals, so a week request answers "when do we play next" for one
    /// league and hands the other a spent result.
    ///
    /// Fourteen days forward is a bye week, the longest a followed team can
    /// go without a fixture; one day back is what lets a game that finished
    /// after midnight survive its `overnightGrace` — ESPN files a 10:30pm
    /// kickoff under the day it started. Still one request per followed
    /// league, so the reload budget is untouched; only the payload grows,
    /// and a fortnight of FBS runs well inside the endpoint's limit.
    static func fetchWindow(around now: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let from = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let to = calendar.date(byAdding: .day, value: 14, to: today) ?? today
        return from...to
    }

    /// The followed games worth showing, best-first: live games (soonest
    /// kickoff first), then upcoming games (soonest first), then the most
    /// recent final. Postponed/canceled games rank last.
    ///
    /// Yesterday's results don't make the list at all — see `isSpent`.
    static func relevantGames(
        in games: [Game], followedKeys: Set<String>, limit: Int, now: Date,
        calendar: Calendar = .current
    ) -> [Game] {
        guard !followedKeys.isEmpty else { return [] }
        struct Ranked {
            let game: Game
            let priority: Int
            let order: TimeInterval
        }
        let followed = games.filter {
            (followedKeys.contains($0.home.team.followKey)
                || followedKeys.contains($0.away.team.followKey))
                && !isSpent($0, now: now, calendar: calendar)
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

    /// Whether a game has stopped being one of "my games". A result is
    /// worth a slot for the day it was played in — the widget is where you
    /// check whether they won — and once tomorrow arrives the question
    /// becomes when they play next, which is a slot this game is holding.
    ///
    /// The same rule clears a canceled game, and a game ESPN never flipped
    /// off `pre`: a kickoff eight hours gone is not upcoming, and left in
    /// the list it would sort ahead of every real fixture. Live games are
    /// exempt — the widget's whole promise is a live score, and no clock
    /// heuristic should be able to suppress one.
    static func isSpent(_ game: Game, now: Date, calendar: Calendar = .current) -> Bool {
        guard !game.isLive, let kickoff = game.date else { return false }
        guard !calendar.isDate(kickoff, inSameDayAs: now) else { return false }
        return now >= kickoff.addingTimeInterval(overnightGrace)
    }

    /// When the widget should ask for a new timeline. Sparse by design:
    /// WidgetKit's daily reload budget is the app's politeness throttle
    /// against ESPN, so a live game polls at 15 minutes, everything else
    /// hourly (pulled earlier if a kickoff lands sooner).
    static func nextRefresh(after now: Date, games: [Game],
                            calendar: Calendar = .current) -> Date {
        if games.contains(where: \.isLive) {
            return now.addingTimeInterval(15 * 60)
        }
        var target = now.addingTimeInterval(60 * 60)

        // Never schedule in the past-adjacent window; give kickoff a beat
        // so ESPN has flipped the game live by the time we refetch.
        let upcoming = games
            .compactMap { game -> Date? in
                guard case .pre = game.status, let date = game.date, date > now else { return nil }
                return date
            }
            .min()
        if let kickoff = upcoming {
            target = min(target, kickoff.addingTimeInterval(60))
        }

        // A result on screen expires at midnight, so ask then rather than
        // on whichever hourly tick happens to land after it — a widget
        // still showing yesterday's slate at 12:40am is the thing this
        // whole rule exists to stop.
        let showsResult = games.contains { game in
            switch game.status {
            case .final, .other: return true
            case .pre, .live: return false
            }
        }
        if showsResult,
           let tomorrow = calendar.date(byAdding: .day, value: 1,
                                        to: calendar.startOfDay(for: now)) {
            target = min(target, tomorrow)
        }

        return max(target, now.addingTimeInterval(60))
    }
}
