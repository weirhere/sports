import AppIntents
import Foundation

/// "What's my next game?" — Siri and Shortcuts answer from the followed
/// teams' schedules without opening the app.
struct NextGameIntent: AppIntent {
    static let title: LocalizedStringResource = "What's My Next Game?"
    static let description = IntentDescription("The next kickoff for the teams you follow.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let followedIds = Set(AppGroup.defaults.stringArray(forKey: AppGroup.followingKey) ?? [])
        guard !followedIds.isEmpty else {
            return .result(dialog: "You're not following any teams yet. Pick your teams in StatSide first.")
        }

        let client = DataProvider.makeClient()
        var gamesById: [String: Game] = [:]
        for teamId in followedIds {
            guard let schedule = try? await client.teamSchedule(teamId: teamId) else { continue }
            for game in schedule.games {
                gamesById[game.id] = game
            }
        }

        if let live = gamesById.values.filter(\.isLive).first {
            return .result(dialog: IntentDialog(stringLiteral: Self.liveLine(for: live)))
        }

        let now = Date.now
        let next = gamesById.values
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
            line += " \(date.formatted(.dateTime.weekday(.wide))) at \(date.formatted(date: .omitted, time: .shortened))"
        }
        if let broadcast = game.broadcast {
            line += " on \(broadcast.split(separator: "/").first.map(String.init) ?? broadcast)"
        }
        return line + "."
    }

    static func liveLine(for game: Game) -> String {
        let away = "\(game.away.team.location) \(game.away.score.map(String.init) ?? "0")"
        let home = "\(game.home.team.location) \(game.home.score.map(String.init) ?? "0")"
        return "Live now: \(away), \(home)."
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
