import Foundation
import os
import UIKit
import WidgetKit

/// Fetches ESPN directly: the widget's promise is a live score at 3:30 on
/// Saturday without the app having been opened, and WidgetKit's daily
/// reload budget keeps the request volume polite (~50/day worst case).
///
/// One request per league you actually follow — so a college-football-only
/// user still spends exactly one, and only somebody following both pays
/// for two. That is what keeps the second league off the politeness
/// budget for everyone who didn't ask for it.
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
        // League-qualified keys ("cfb:130", "nfl:26").
        let followedKeys = Set(defaults.stringArray(forKey: AppGroup.followingKeysKey) ?? [])
        let leagues = followedKeys.followedLeagues
        guard !leagues.isEmpty else {
            return (NextGameEntry(date: now, state: .noFollows), now.addingTimeInterval(60 * 60))
        }

        let boards = await Self.currentGames(in: leagues)
        // A partial outage is not an outage: one league answering is enough
        // to render, and only losing every league falls back to the stale
        // snapshot. Otherwise an NFL hiccup would blank a Saturday.
        if boards.contains(where: { $0 != nil }) {
            let games = boards.compactMap(\.self).flatMap { $0 }
            // 4 fills the large family; medium trims to its own capacity.
            // One limit for every family: the snapshot below is a single
            // shared blob, and a per-family limit would let a medium reload
            // overwrite it with too few games for a placed large.
            //
            // The pick is cross-league and purely chronological, which is
            // the right answer for "my games": a Sunday NFL kickoff can
            // outrank a Saturday that has already finished.
            let relevant = GameSelection.relevantGames(
                in: games, followedKeys: followedKeys, limit: 4, now: now
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
        } else {
            Self.logger.error("Widget fetch failed for every followed league")
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
                        statusDetail: game.statusDetail,
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

    /// Each league's current slate, in flight together. `nil` marks a league
    /// that failed, so the caller can tell "nobody plays" from "nobody
    /// answered" — the two look identical in a flattened list of games.
    private static func currentGames(in leagues: [League]) async -> [[Game]?] {
        await withTaskGroup(of: [Game]?.self) { group in
            for league in leagues {
                group.addTask {
                    try? await DataProvider.makeClient(league: league)
                        .scoreboard(weekValue: nil, seasonType: nil, year: nil).games
                }
            }
            return await group.reduce(into: [[Game]?]()) { $0.append($1) }
        }
    }
}
