import Foundation
import Observation

/// One team page's season numbers and leaders, fetched once per visit.
///
/// Leaders arrive from the core API as bare athlete ids, so they are
/// resolved here: first against the team's own roster (one request, and
/// the one the Roster tab makes anyway), then — only for the few ids the
/// roster can't place, a player traded since the season the leaders
/// describe — against the core athlete record. A leader nothing can name
/// is dropped rather than shown as a number with no person.
@Observable
@MainActor
final class TeamStatsModel {
    struct Leader: Identifiable, Hashable {
        let entry: TeamLeader
        let name: String
        let headshotURL: URL?
        /// Pushable where the roster knew them; a player since traded
        /// away still gets a page, from the id alone.
        let player: PlayerIdentity
        var id: String { entry.id }
    }

    let team: Team

    private(set) var stats: TeamSeasonStats?
    private(set) var leaders: [Leader]?
    /// "2025-26" when the leaders fell back a season — see
    /// `TeamStatsClient.leaders`.
    private(set) var leadersSeasonLabel: String?

    @ObservationIgnored private let client = TeamStatsClient()

    init(team: Team) {
        self.team = team
    }

    private var league: League { team.league }

    func load() async {
        guard stats == nil else { return }
        async let stats = client.stats(teamId: team.id, league: league)
        async let leaders = loadLeaders()
        let (loadedStats, _) = await (stats, leaders)
        guard !Task.isCancelled else { return }
        self.stats = loadedStats
    }

    private func loadLeaders() async {
        // The app-wide season clock, as the player page's This season card uses:
        // in September an NBA team's "now" is 2026-27, which has no leaders
        // yet, so the fallback runs and the card says whose season it shows.
        let season = league.espnSeason(for: SeasonSpan.year(containing: .now))
        let (entries, answered) = await client.leaders(teamId: team.id, league: league, season: season)
        guard !entries.isEmpty, let answered else {
            leaders = []
            return
        }
        let roster = (try? await DataProvider.makeClient(league: league).roster(teamId: team.id)) ?? .empty
        let byId = Dictionary(roster.groups.flatMap(\.players).map { ($0.id, $0) },
                              uniquingKeysWith: { first, _ in first })

        var resolved: [Leader] = []
        for entry in entries {
            if let player = byId[entry.athleteId] {
                resolved.append(Leader(entry: entry, name: player.name,
                                       headshotURL: player.headshotURL,
                                       player: PlayerIdentity(player: player, team: team, league: league)))
            } else if let found = await client.athlete(id: entry.athleteId, league: league, season: answered) {
                resolved.append(Leader(entry: entry, name: found.name, headshotURL: found.headshot,
                                       player: PlayerIdentity(athleteId: entry.athleteId, name: found.name,
                                                              league: league, teamName: nil,
                                                              headshotURL: found.headshot)))
            }
        }
        guard !Task.isCancelled else { return }
        leaders = resolved
        leadersSeasonLabel = answered == season ? nil : league.seasonLabel(league.seasonYear(fromESPN: answered))
    }
}
