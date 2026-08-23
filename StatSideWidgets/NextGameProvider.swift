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
            // 4 fills the large family; medium trims to its own capacity.
            // One limit for every family: the snapshot below is a single
            // shared blob, and a per-family limit would let a medium reload
            // overwrite it with too few games for a placed large.
            let relevant = GameSelection.relevantGames(
                in: scoreboard.games, followedIds: followedIds, limit: 4, now: now
            )
            guard !relevant.isEmpty else {
                return (NextGameEntry(date: now, state: .noGames), now.addingTimeInterval(60 * 60))
            }
            WidgetSnapshot(games: relevant).save(to: defaults)
            var widgetGames: [WidgetGame] = []
            for game in relevant {
                // Both variants per team: views render pre-fetched images,
                // so the dark-mode pick has to be in hand before render.
                async let away = WidgetLogoFetcher.logo(for: game.away.team.logoURL)
                async let awayDark = WidgetLogoFetcher.logo(for: game.away.team.logoURL?.darkTeamLogoVariant)
                async let home = WidgetLogoFetcher.logo(for: game.home.team.logoURL)
                async let homeDark = WidgetLogoFetcher.logo(for: game.home.team.logoURL?.darkTeamLogoVariant)
                widgetGames.append(WidgetGame(game: game,
                                              awayLogo: await away, awayDarkLogo: await awayDark,
                                              homeLogo: await home, homeDarkLogo: await homeDark))
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
                                             record: game.awayRecord,
                                             score: game.awayScore, muted: game.awayMuted,
                                             logo: WidgetLogoFetcher.cachedLogo(for: game.awayLogoURL),
                                             darkLogo: WidgetLogoFetcher.cachedLogo(for: game.awayLogoURL?.darkTeamLogoVariant)),
                        home: WidgetTeamLine(abbreviation: game.homeAbbreviation, rank: game.homeRank,
                                             record: game.homeRecord,
                                             score: game.homeScore, muted: game.homeMuted,
                                             logo: WidgetLogoFetcher.cachedLogo(for: game.homeLogoURL),
                                             darkLogo: WidgetLogoFetcher.cachedLogo(for: game.homeLogoURL?.darkTeamLogoVariant)),
                        statusLine: game.statusLine,
                        network: game.network,
                        isLive: game.isLive,
                        showsScores: game.showsScores ?? true
                    )
                }
                // Dated at the snapshot's save, not now: the stale marker's
                // "as of" should say when the data was true.
                return (NextGameEntry(date: snapshot.savedAt, state: .games(games, stale: true)),
                        now.addingTimeInterval(15 * 60))
            }
            return (NextGameEntry(date: now, state: .noGames), now.addingTimeInterval(15 * 60))
        }
    }
}
