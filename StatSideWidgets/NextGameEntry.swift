import Foundation
import UIKit
import WidgetKit

nonisolated struct NextGameEntry: TimelineEntry {
    let date: Date
    let state: WidgetEntryState

    static var sample: NextGameEntry {
        NextGameEntry(date: .now, state: .games([.sampleLive], stale: false))
    }

    /// Enough games to fill the large family's five rows in previews and
    /// the gallery snapshot: one live, three pre (scoreless), one final.
    static var sampleFull: NextGameEntry {
        NextGameEntry(date: .now, state: .games([
            .sampleLive,
            WidgetGame(id: "1",
                       away: WidgetTeamLine(abbreviation: "BALL", rank: nil, record: "0-0", score: nil, muted: false, logo: nil, darkLogo: nil),
                       home: WidgetTeamLine(abbreviation: "OSU", rank: 1, record: "0-0", score: nil, muted: false, logo: nil, darkLogo: nil),
                       statusLine: "Sat 12:30 PM", isLive: false, showsScores: false),
            WidgetGame(id: "2",
                       away: WidgetTeamLine(abbreviation: "KENT", rank: nil, record: "0-0", score: nil, muted: false, logo: nil, darkLogo: nil),
                       home: WidgetTeamLine(abbreviation: "SC", rank: nil, record: "0-0", score: nil, muted: false, logo: nil, darkLogo: nil),
                       statusLine: "Sat 12:45 PM", isLive: false, showsScores: false),
            WidgetGame(id: "3",
                       away: WidgetTeamLine(abbreviation: "FIU", rank: nil, record: "0-0", score: nil, muted: false, logo: nil, darkLogo: nil),
                       home: WidgetTeamLine(abbreviation: "USF", rank: nil, record: "0-0", score: nil, muted: false, logo: nil, darkLogo: nil),
                       statusLine: "Sat 7:00 PM", isLive: false, showsScores: false),
            WidgetGame(id: "4",
                       away: WidgetTeamLine(abbreviation: "AUB", rank: nil, record: "5-3", score: 13, muted: true, logo: nil, darkLogo: nil),
                       home: WidgetTeamLine(abbreviation: "BAMA", rank: 8, record: "7-1", score: 27, muted: false, logo: nil, darkLogo: nil),
                       statusLine: "FINAL", isLive: false, showsScores: true),
        ], stale: false))
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
    /// Pre-game rows carry no scores at all — no zeros, no dashes; the
    /// kickoff time is the row's whole story until the game starts.
    let showsScores: Bool

    var deepLink: URL? { URL(string: "statside://game/\(id)") }

    static var sampleLive: WidgetGame {
        WidgetGame(
            id: "0",
            away: WidgetTeamLine(abbreviation: "UGA", rank: 3, record: "5-0", score: 24, muted: false, logo: nil, darkLogo: nil),
            home: WidgetTeamLine(abbreviation: "TENN", rank: 12, record: "4-1", score: 17, muted: false, logo: nil, darkLogo: nil),
            statusLine: "Q3 5:24", isLive: true, showsScores: true
        )
    }
}

nonisolated struct WidgetTeamLine {
    let abbreviation: String
    let rank: Int?
    /// Overall record summary ("4-1"), shown in every game state — the
    /// record stays put when the game goes live rather than vanishing
    /// mid-Saturday.
    let record: String?
    let score: Int?
    let muted: Bool
    let logo: UIImage?
    /// The ESPN `500-dark` mark, when the team has one; the view picks it
    /// in dark mode and falls back to `logo` otherwise.
    let darkLogo: UIImage?
}

// MARK: - Building from the domain model
// The same status grammar as GameRow: quiet pre/final, "Q3 5:24" live.

nonisolated extension WidgetGame {
    init(game: Game, awayLogo: UIImage?, awayDarkLogo: UIImage?,
         homeLogo: UIImage?, homeDarkLogo: UIImage?) {
        let awayMuted: Bool
        let homeMuted: Bool
        if case .final = game.status {
            awayMuted = game.home.winner == true
            homeMuted = game.away.winner == true
        } else {
            awayMuted = false
            homeMuted = false
        }
        let isPre: Bool
        if case .pre = game.status { isPre = true } else { isPre = false }
        self.init(
            id: game.id,
            away: WidgetTeamLine(competitor: game.away, muted: awayMuted,
                                 logo: awayLogo, darkLogo: awayDarkLogo),
            home: WidgetTeamLine(competitor: game.home, muted: homeMuted,
                                 logo: homeLogo, darkLogo: homeDarkLogo),
            statusLine: Self.statusLine(for: game),
            isLive: game.isLive,
            showsScores: !isPre
        )
    }

    static func statusLine(for game: Game) -> String {
        switch game.status {
        case .pre:
            // Time only — no network, the row hasn't the room. Absolute
            // dates (never "Today"): widget strings outlive the moment
            // they're generated. The date joins once a bare weekday would
            // lie — a week or more out, "Sat" means *this* Saturday.
            guard let date = game.date else { return "TBD" }
            let time = date.formatted(.dateTime.hour().minute())
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day],
                                               from: calendar.startOfDay(for: .now),
                                               to: calendar.startOfDay(for: date)).day ?? 0
            let weekday = Date.FormatStyle.dateTime.weekday(.abbreviated)
            let day = date.formatted(days < 7 ? weekday : weekday.month(.defaultDigits).day())
            return "\(day) \(time)"
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
    init(competitor: Competitor, muted: Bool, logo: UIImage?, darkLogo: UIImage?) {
        self.init(
            abbreviation: competitor.team.abbreviation ?? competitor.team.location,
            rank: competitor.rank,
            record: competitor.record,
            score: competitor.score,
            muted: muted,
            logo: logo,
            darkLogo: darkLogo
        )
    }
}

// MARK: - Last-good snapshot
// What the provider parks in the App Group after every successful fetch, so
// a network failure re-serves yesterday's truth marked stale instead of a
// blank widget. Images stay out; the disk logo cache re-hydrates them (the
// dark variant's URL is derived from the stored light one, never persisted).

nonisolated struct WidgetSnapshot: Codable {
    struct SnapshotGame: Codable {
        let id: String
        let awayAbbreviation: String
        let awayRank: Int?
        /// Optional so snapshots written before records shipped still
        /// decode; those rows just omit the record for one stale cycle.
        let awayRecord: String?
        let awayScore: Int?
        let awayMuted: Bool
        let awayLogoURL: URL?
        let homeAbbreviation: String
        let homeRank: Int?
        let homeRecord: String?
        let homeScore: Int?
        let homeMuted: Bool
        let homeLogoURL: URL?
        let statusLine: String
        let isLive: Bool
        /// Optional so snapshots written before the scoreless-pre-game
        /// change still decode; they render scores for one stale cycle.
        let showsScores: Bool?
    }

    let games: [SnapshotGame]
    let savedAt: Date

    init(games: [Game]) {
        savedAt = .now
        self.games = games.map { game in
            let widgetGame = WidgetGame(game: game, awayLogo: nil, awayDarkLogo: nil,
                                        homeLogo: nil, homeDarkLogo: nil)
            return SnapshotGame(
                id: game.id,
                awayAbbreviation: widgetGame.away.abbreviation,
                awayRank: widgetGame.away.rank,
                awayRecord: widgetGame.away.record,
                awayScore: widgetGame.away.score,
                awayMuted: widgetGame.away.muted,
                awayLogoURL: game.away.team.logoURL,
                homeAbbreviation: widgetGame.home.abbreviation,
                homeRank: widgetGame.home.rank,
                homeRecord: widgetGame.home.record,
                homeScore: widgetGame.home.score,
                homeMuted: widgetGame.home.muted,
                homeLogoURL: game.home.team.logoURL,
                statusLine: widgetGame.statusLine,
                isLive: widgetGame.isLive,
                showsScores: widgetGame.showsScores
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
