import Foundation
import os
import UIKit
import WidgetKit

/// Fetches ESPN directly: the widget's promise is a live score at 3:30 on
/// Saturday without the app having been opened, and WidgetKit's daily
/// reload budget keeps the request volume polite (~50/day worst case).
/// `nonisolated` because the target defaults to MainActor and provider
/// callbacks should not hop.
nonisolated struct NextGameProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "widget")

    func placeholder(in context: Context) -> NextGameEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (NextGameEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        Task {
            let (entry, _) = await currentEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<NextGameEntry>) -> Void) {
        Task {
            let (entry, refresh) = await currentEntry()
            Self.logger.info("Widget timeline built; next refresh \(refresh.formatted(), privacy: .public)")
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    // MARK: - Entry building

    private func currentEntry() async -> (NextGameEntry, refresh: Date) {
        let now = Date.now
        let defaults = AppGroup.defaults
        let followedIds = Set(defaults.stringArray(forKey: AppGroup.followingKey) ?? [])
        guard !followedIds.isEmpty else {
            return (NextGameEntry(date: now, state: .noFollows), now.addingTimeInterval(60 * 60))
        }

        do {
            let scoreboard = try await DataProvider.makeClient()
                .scoreboard(weekValue: nil, seasonType: nil, year: nil)
            let relevant = GameSelection.relevantGames(
                in: scoreboard.games, followedIds: followedIds, limit: 3, now: now
            )
            guard !relevant.isEmpty else {
                return (NextGameEntry(date: now, state: .noGames), now.addingTimeInterval(60 * 60))
            }
            WidgetSnapshot(games: relevant).save(to: defaults)
            var widgetGames: [WidgetGame] = []
            for game in relevant {
                async let away = WidgetLogoFetcher.logo(for: game.away.team.logoURL)
                async let home = WidgetLogoFetcher.logo(for: game.home.team.logoURL)
                widgetGames.append(WidgetGame(game: game, awayLogo: await away, homeLogo: await home))
            }
            let entry = NextGameEntry(date: now, state: .games(widgetGames, stale: false))
            return (entry, GameSelection.nextRefresh(after: now, games: relevant))
        } catch {
            Self.logger.error("Widget fetch failed: \(error, privacy: .public)")
            // Last-good beats blank: re-serve the snapshot marked stale and
            // retry on a short leash.
            if let snapshot = WidgetSnapshot.load(from: defaults) {
                let games = snapshot.games.map { game in
                    WidgetGame(
                        id: game.id,
                        away: WidgetTeamLine(abbreviation: game.awayAbbreviation, rank: game.awayRank,
                                             score: game.awayScore, muted: game.awayMuted,
                                             logo: WidgetLogoFetcher.cachedLogo(for: game.awayLogoURL)),
                        home: WidgetTeamLine(abbreviation: game.homeAbbreviation, rank: game.homeRank,
                                             score: game.homeScore, muted: game.homeMuted,
                                             logo: WidgetLogoFetcher.cachedLogo(for: game.homeLogoURL)),
                        statusLine: game.statusLine,
                        isLive: game.isLive
                    )
                }
                return (NextGameEntry(date: now, state: .games(games, stale: true)),
                        now.addingTimeInterval(15 * 60))
            }
            return (NextGameEntry(date: now, state: .noGames), now.addingTimeInterval(15 * 60))
        }
    }
}
