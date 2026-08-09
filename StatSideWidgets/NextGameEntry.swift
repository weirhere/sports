import Foundation
import UIKit
import WidgetKit

nonisolated struct NextGameEntry: TimelineEntry {
    let date: Date
    let state: WidgetEntryState

    static var sample: NextGameEntry {
        let georgia = WidgetTeamLine(abbreviation: "UGA", rank: 3, score: 24, muted: false, logo: nil)
        let tennessee = WidgetTeamLine(abbreviation: "TENN", rank: 12, score: 17, muted: false, logo: nil)
        let game = WidgetGame(
            id: "0", away: georgia, home: tennessee, statusLine: "Q3 5:24", isLive: true
        )
        return NextGameEntry(date: .now, state: .games([game], stale: false))
    }
}

nonisolated enum WidgetEntryState {
    case games([WidgetGame], stale: Bool)
    case noFollows
    case noGames
}

nonisolated struct WidgetGame: Identifiable {
    let id: String
    let away: WidgetTeamLine
    let home: WidgetTeamLine
    let statusLine: String
    let isLive: Bool

    var deepLink: URL? { URL(string: "statside://game/\(id)") }
}

nonisolated struct WidgetTeamLine {
    let abbreviation: String
    let rank: Int?
    let score: Int?
    let muted: Bool
    let logo: UIImage?
}

// MARK: - Building from the domain model
// The same status grammar as GameRow: quiet pre/final, "Q3 5:24" live.

nonisolated extension WidgetGame {
    init(game: Game, awayLogo: UIImage?, homeLogo: UIImage?) {
        let awayMuted: Bool
        let homeMuted: Bool
        if case .final = game.status {
            awayMuted = game.home.winner == true
            homeMuted = game.away.winner == true
        } else {
            awayMuted = false
            homeMuted = false
        }
        self.init(
            id: game.id,
            away: WidgetTeamLine(competitor: game.away, muted: awayMuted, logo: awayLogo),
            home: WidgetTeamLine(competitor: game.home, muted: homeMuted, logo: homeLogo),
            statusLine: Self.statusLine(for: game),
            isLive: game.isLive
        )
    }

    static func statusLine(for game: Game) -> String {
        switch game.status {
        case .pre:
            var parts = [game.date.map { $0.formatted(.dateTime.weekday(.abbreviated).hour().minute()) } ?? "TBD"]
            if let broadcast = game.broadcast {
                parts.append(broadcast.split(separator: "/").first.map(String.init) ?? broadcast)
            }
            return parts.joined(separator: " · ")
        case .live(let clock, let period, let detail, _):
            let quarter = period.map { $0 <= 4 ? "Q\($0)" : ($0 == 5 ? "OT" : "\($0 - 4)OT") }
            let line = [quarter, clock].compactMap(\.self).joined(separator: " ")
            return line.isEmpty ? (detail ?? "Live") : line
        case .final(let detail):
            if let detail, detail.localizedCaseInsensitiveContains("OT") { return "FINAL OT" }
            return "FINAL"
        case .other(let detail):
            return detail ?? "—"
        }
    }
}

nonisolated extension WidgetTeamLine {
    init(competitor: Competitor, muted: Bool, logo: UIImage?) {
        self.init(
            abbreviation: competitor.team.abbreviation ?? competitor.team.location,
            rank: competitor.rank,
            score: competitor.score,
            muted: muted,
            logo: logo
        )
    }
}

// MARK: - Last-good snapshot
// What the provider parks in the App Group after every successful fetch, so
// a network failure re-serves yesterday's truth marked stale instead of a
// blank widget. Images stay out; the disk logo cache re-hydrates them.

nonisolated struct WidgetSnapshot: Codable {
    struct SnapshotGame: Codable {
        let id: String
        let awayAbbreviation: String
        let awayRank: Int?
        let awayScore: Int?
        let awayMuted: Bool
        let awayLogoURL: URL?
        let homeAbbreviation: String
        let homeRank: Int?
        let homeScore: Int?
        let homeMuted: Bool
        let homeLogoURL: URL?
        let statusLine: String
        let isLive: Bool
    }

    let games: [SnapshotGame]
    let savedAt: Date

    init(games: [Game]) {
        savedAt = .now
        self.games = games.map { game in
            let widgetGame = WidgetGame(game: game, awayLogo: nil, homeLogo: nil)
            return SnapshotGame(
                id: game.id,
                awayAbbreviation: widgetGame.away.abbreviation,
                awayRank: widgetGame.away.rank,
                awayScore: widgetGame.away.score,
                awayMuted: widgetGame.away.muted,
                awayLogoURL: game.away.team.logoURL,
                homeAbbreviation: widgetGame.home.abbreviation,
                homeRank: widgetGame.home.rank,
                homeScore: widgetGame.home.score,
                homeMuted: widgetGame.home.muted,
                homeLogoURL: game.home.team.logoURL,
                statusLine: widgetGame.statusLine,
                isLive: widgetGame.isLive
            )
        }
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: AppGroup.snapshotKey)
        }
    }

    static func load(from defaults: UserDefaults) -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: AppGroup.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
