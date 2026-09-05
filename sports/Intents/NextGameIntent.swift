import AppIntents
import Foundation

/// "What's my next game?" — Siri and Shortcuts answer from the followed
/// teams' schedules without opening the app.
struct NextGameIntent: AppIntent {
    static let title: LocalizedStringResource = "What's My Next Game?"
    static let description = IntentDescription("The next kickoff for the teams you follow.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // League-qualified keys; college football only for now (M5 widens
        // the intent to both leagues alongside the widget).
        let followedKeys = Set(AppGroup.defaults.stringArray(forKey: AppGroup.followingKeysKey) ?? [])
            .filter { $0.hasPrefix("\(League.collegeFootball.rawValue):") }
        guard !followedKeys.isEmpty else {
            return .result(dialog: "You're not following any teams yet. Pick your teams in StatSide first.")
        }

        let client = DataProvider.makeClient(league: .collegeFootball)
        // A team's schedule knows which games exist; it does not know how
        // one is going. The payload carries no live score and no clock
        // once a game kicks off (the dashed-score bug, Andy 2026-08-29),
        // so an answer built from it alone had to invent a score — and
        // said "0, 0" out loud, mid-drive. The scoreboard is the app's one
        // live source, fetched here alongside the schedules and merged the
        // same way TeamPage and ConferencePage merge it.
        async let board: Scoreboard? = try? await client.scoreboard(
            weekValue: nil, seasonType: nil, year: nil)
        var gamesById: [String: Game] = [:]
        let prefix = "\(League.collegeFootball.rawValue):"
        for teamId in followedKeys.map({ String($0.dropFirst(prefix.count)) }) {
            guard let schedule = try? await client.teamSchedule(teamId: teamId) else { continue }
            for game in schedule.games {
                gamesById[game.id] = game
            }
        }
        let games = Game.merging(Array(gamesById.values), withLive: await board?.games ?? [])

        // Earliest kickoff among the live ones — a Dictionary's values have
        // no order, so "the first live game" was a different game run to
        // run when two followed teams played at once.
        let live = games
            .filter(\.isLive)
            .min { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        if let live {
            return .result(dialog: IntentDialog(stringLiteral: Self.liveLine(for: live)))
        }

        let now = Date.now
        let next = games
            .filter { game in
                guard case .pre = game.status, let date = game.date else { return false }
                return date > now
            }
            .min { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        guard let next else {
            return .result(dialog: "No upcoming games for your teams right now.")
        }
        return .result(dialog: IntentDialog(stringLiteral: Self.nextLine(for: next)))
    }

    static func nextLine(for game: Game) -> String {
        var line = "\(game.away.team.location) plays \(game.home.team.location)"
        if let date = game.date {
            line += " \(date.formatted(.dateTime.weekday(.wide)))"
            line += game.timeTBD
                ? ", time to be announced"
                : " at \(date.formatted(date: .omitted, time: .shortened))"
        }
        if let broadcast = game.broadcast {
            line += " on \(broadcast.split(separator: "/").first.map(String.init) ?? broadcast)"
        }
        return line + "."
    }

    static func liveLine(for game: Game) -> String {
        // Never invent a score. If the merge found no live copy of this
        // game, the honest answer is that it's on — the app's own rule for
        // the same gap ("Live", never a dashed non-score).
        guard let awayScore = game.away.score, let homeScore = game.home.score else {
            let sides = "\(game.away.team.location) and \(game.home.team.location)"
            let clock = Self.spokenClock(game).map { ", \($0)" } ?? ""
            return "\(sides) are playing right now\(clock)."
        }
        let score = "\(game.away.team.location) \(awayScore), \(game.home.team.location) \(homeScore)"
        guard let clock = Self.spokenClock(game) else { return "Live now: \(score)." }
        return "Live now: \(score), \(clock)."
    }

    /// Siri speaks the line, so the row's "Q3 5:24" shorthand is spelled
    /// out — and the halftime rule holds: a parked clock is a break, not a
    /// quarter running out (decision log, 2026-08-31).
    static func spokenClock(_ game: Game) -> String? {
        guard case .live(let clock, let period, _, let phase, _) = game.status else { return nil }
        switch phase {
        case .halftime:
            return "at halftime"
        case .endOfPeriod:
            return period.map { "at the end of the \(Self.ordinal($0)) quarter" }
        case .playing:
            guard let period else { return nil }
            let quarter = period > 4
                ? "in overtime"
                : "in the \(Self.ordinal(period)) quarter"
            return clock.map { "\(quarter), \($0) left" } ?? quarter
        }
    }

    private static func ordinal(_ value: Int) -> String {
        switch value {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(value)th"
        }
    }
}

struct StatSideShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextGameIntent(),
            phrases: [
                "What's my next game in \(.applicationName)",
                "When do my teams play in \(.applicationName)",
            ],
            shortTitle: "Next Game",
            systemImageName: "football"
        )
    }
}
