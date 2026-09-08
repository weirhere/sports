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
                       statusLine: "Sat, Sep 5", statusDetail: "12:30 PM", network: "FOX", isLive: false, showsScores: false),
            WidgetGame(id: "2",
                       away: WidgetTeamLine(abbreviation: "KENT", rank: nil, record: "0-0", score: nil, muted: false, logo: nil, darkLogo: nil),
                       home: WidgetTeamLine(abbreviation: "SC", rank: nil, record: "0-0", score: nil, muted: false, logo: nil, darkLogo: nil),
                       statusLine: "Sat, Sep 5", statusDetail: "12:45 PM", network: "ESPN2", isLive: false, showsScores: false),
            WidgetGame(id: "3",
                       away: WidgetTeamLine(abbreviation: "FIU", rank: nil, record: "0-0", score: nil, muted: false, logo: nil, darkLogo: nil),
                       home: WidgetTeamLine(abbreviation: "USF", rank: nil, record: "0-0", score: nil, muted: false, logo: nil, darkLogo: nil),
                       statusLine: "Sat, Sep 5", statusDetail: "7:00 PM", network: "ABC", isLive: false, showsScores: false),
            WidgetGame(id: "4",
                       away: WidgetTeamLine(abbreviation: "AUB", rank: nil, record: "5-3", score: 13, muted: true, logo: nil, darkLogo: nil),
                       home: WidgetTeamLine(abbreviation: "BAMA", rank: 8, record: "7-1", score: 27, muted: false, logo: nil, darkLogo: nil),
                       statusLine: "FINAL", statusDetail: nil, network: nil, isLive: false, showsScores: true),
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
    /// The kickoff time, on its own line under the day (Andy, 2026-09-06:
    /// the NFL's times were truncating). A pre-game row spends its day part
    /// on "Sun, Sep 13", and "Sun, Sep 13 1:00 PM" does not fit a 64pt
    /// column at any text size — so day and time split the way the app's
    /// own `GameRow` splits them. Nil for live and final rows, whose status
    /// is one word.
    let statusDetail: String?
    /// Third status line: the TV network, pre-game and live only — a
    /// final row has nothing left to tune into.
    let network: String?
    let isLive: Bool
    /// Pre-game rows carry no scores at all — no zeros, no dashes; the
    /// kickoff time is the row's whole story until the game starts.
    let showsScores: Bool
    /// Kickoff, carried purely so the tap can say which day to open. The
    /// widget lists games from yesterday to a fortnight out and the app
    /// holds five days at a time, so an id alone lands nowhere for most of
    /// this list (Andy, 2026-09-07). Defaulted for the samples, and
    /// optional in the snapshot — a row that has lost its day still opens
    /// whatever it can, exactly as every row used to.
    var day: Date? = nil

    var deepLink: URL? { DeepLinkURL.game(id: id, day: day) }

    static var sampleLive: WidgetGame {
        WidgetGame(
            id: "0",
            away: WidgetTeamLine(abbreviation: "UGA", rank: 3, record: "5-0", score: 24, muted: false, logo: nil, darkLogo: nil),
            home: WidgetTeamLine(abbreviation: "TENN", rank: 12, record: "4-1", score: 17, muted: false, logo: nil, darkLogo: nil),
            statusLine: "Q3 5:24", statusDetail: nil, network: "CBS", isLive: true, showsScores: true
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
            statusLine: Self.status(for: game).line,
            statusDetail: Self.status(for: game).detail,
            network: (isPre || game.isLive) ? game.broadcast : nil,
            isLive: game.isLive,
            showsScores: !isPre,
            day: game.date
        )
    }

    /// The status column's lines: a headline and, for a kickoff, the time
    /// beneath it. Two values rather than one joined string because the
    /// column is a fixed 64pt and the joined form overflowed it — see
    /// `statusDetail`.
    static func status(for game: Game) -> (line: String, detail: String?) {
        switch game.status {
        case .pre:
            // Absolute dates (never "Today"): widget strings outlive the
            // moment they're generated — and they always name the month,
            // since a widget row carries no strip or header to say which
            // week you're looking at.
            guard let date = game.date else { return ("TBD", nil) }
            let time = game.timeTBD ? "TBD" : date.formatted(.dateTime.hour().minute())
            let day = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            return (day, time)
        case .live:
            return (game.status.liveStatusText ?? "Live", nil)
        case .final(let detail):
            if let detail, detail.localizedCaseInsensitiveContains("OT") { return ("FINAL OT", nil) }
            return ("FINAL", nil)
        case .other(let detail):
            return (detail ?? "—", nil)
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
        /// Optional twice over: only kickoffs carry one, and snapshots
        /// written before the time moved to its own line still decode —
        /// those rows show the day without the time for one stale cycle.
        let statusDetail: String?
        /// Optional twice over: finals carry none, and snapshots written
        /// before the network line shipped still decode.
        let network: String?
        let isLive: Bool
        /// Optional so snapshots written before the scoreless-pre-game
        /// change still decode; they render scores for one stale cycle.
        let showsScores: Bool?
        /// Kickoff, for the row's deep link. Optional on the same terms —
        /// an older blob's rows just open without a day hint.
        let day: Date?
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
                statusDetail: widgetGame.statusDetail,
                network: widgetGame.network,
                isLive: widgetGame.isLive,
                showsScores: widgetGame.showsScores,
                day: widgetGame.day
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
