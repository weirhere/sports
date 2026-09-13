import Foundation

/// Assembling a head-to-head series out of schedules, because ESPN has no
/// resource that answers the question directly.
///
/// The site summary's `seasonseries` is the closest thing and it is not
/// close: it carries *this season's* meetings only (verified against the
/// captured NBA and NHL summaries — four Knicks-Nets games, "NY wins series
/// 4-0"), and college football's summary ships none at all. A series worth
/// a tab has to be walked out of one team's schedules, one season at a
/// time, which is what this does.
nonisolated extension ScoresProviding {
    /// The completed meetings between the two sides of `game`, newest
    /// first, with the tally they add up to.
    ///
    /// Anchored on the game's own season and looking back
    /// `League.headToHeadSeasons` of them — so a 2019 page shows the series
    /// as it stood in 2019 rather than everything that has happened since.
    ///
    /// Only one team's schedules are fetched: a meeting is in both sides'
    /// schedules, so asking twice would double the bill to learn nothing.
    /// The home side is the one asked, arbitrarily — a neutral-site game
    /// has no home in any meaningful sense and both are equally covered.
    ///
    /// A season that fails is dropped rather than failing the series; a
    /// series where *every* season failed throws, because an empty answer
    /// and a broken one look identical on screen and only one of them
    /// should say "no meetings".
    func headToHead(for game: Game,
                    calendar: Calendar = .current) async throws -> HeadToHead {
        let league = game.home.team.league
        let anchorSeason = SeasonYear.year(for: league, now: game.date ?? .now,
                                           calendar: calendar)
        let earliest = anchorSeason - league.headToHeadSeasons + 1
        let games = try await seasons(of: game.home.team.id,
                                      from: earliest, through: anchorSeason)
        return HeadToHead.make(from: games, anchor: game, earliestSeason: earliest)
    }

    /// One team's seasons across a window, fetched a few at a time.
    ///
    /// Bounded rather than fired off at once: ten seasons is twenty
    /// requests, and twenty at once is not what "be a polite guest" means
    /// even for a one-shot. `URLSession` would queue them at six per host
    /// anyway — this just makes the throttle ours and deliberate, at a
    /// width that still hides the round-trip latency.
    private func seasons(of teamId: String, from earliest: Int,
                         through latest: Int) async throws -> [Game] {
        guard earliest <= latest else { return [] }
        let width = 3
        var collected: [Game] = []
        var succeeded = false
        await withTaskGroup(of: Optional<[Game]>.self) { group in
            var next = earliest
            for _ in 0..<width {
                guard next <= latest else { break }
                let year = next
                next += 1
                group.addTask { [self] in try? await seasonGames(teamId: teamId, year: year) }
            }
            while let season = await group.next() {
                if let season {
                    succeeded = true
                    collected += season
                }
                guard next <= latest else { continue }
                let year = next
                next += 1
                group.addTask { [self] in try? await seasonGames(teamId: teamId, year: year) }
            }
        }
        guard succeeded else { throw ESPNError.nothingFetched }
        return collected
    }
}
