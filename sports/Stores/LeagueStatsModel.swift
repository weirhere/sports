import Foundation
import Observation

/// One league page's Team stats and Player stats tabs: the league's
/// `byteam` table and its `byathlete` pools per season, each fetched on its
/// tab's first visit and kept for the page — so flipping the season chip
/// back to a year already seen costs nothing (ConferencePage's per-year
/// caching rule).
@Observable
@MainActor
final class LeagueStatsModel {
    let league: League

    private(set) var statsByYear: [Int: LeagueTeamStats] = [:]
    private(set) var failedYears: Set<Int> = []
    private var loadingYears: Set<Int> = []

    private(set) var playersByYear: [Int: LeaguePlayerStats] = [:]
    private(set) var playersFailedYears: Set<Int> = []
    private var playersLoadingYears: Set<Int> = []

    private(set) var standingsByYear: [Int: [ConferenceStandings]] = [:]
    private var standingsLoadingYears: Set<Int> = []

    @ObservationIgnored private let client = TeamStatsClient()
    @ObservationIgnored private let playerClient = LeaguePlayerStatsClient()

    init(league: League) {
        self.league = league
    }

    func stats(for year: Int) -> LeagueTeamStats? { statsByYear[year] }
    func failed(_ year: Int) -> Bool { failedYears.contains(year) }

    func load(year: Int, force: Bool = false) async {
        guard statsByYear[year] == nil || force, !loadingYears.contains(year) else { return }
        loadingYears.insert(year)
        defer { loadingYears.remove(year) }
        do {
            let stats = try await client.leagueTeamStats(league: league,
                                                         season: league.espnSeason(for: year))
            guard !Task.isCancelled else { return }
            statsByYear[year] = stats
            failedYears.remove(year)
        } catch {
            guard !Task.isCancelled else { return }
            failedYears.insert(year)
        }
    }

    func players(for year: Int) -> LeaguePlayerStats? { playersByYear[year] }
    func playersFailed(_ year: Int) -> Bool { playersFailedYears.contains(year) }

    func loadPlayers(year: Int, force: Bool = false) async {
        guard playersByYear[year] == nil || force, !playersLoadingYears.contains(year) else { return }
        playersLoadingYears.insert(year)
        defer { playersLoadingYears.remove(year) }
        do {
            let players = try await playerClient.stats(league: league, season: league.espnSeason(for: year))
            guard !Task.isCancelled else { return }
            playersByYear[year] = players
            playersFailedYears.remove(year)
        } catch {
            guard !Task.isCancelled else { return }
            playersFailedYears.insert(year)
        }
    }

    /// FBS standings for a page that doesn't already have them — the Top
    /// 25's own Standings tab is the poll, not a table. They lend the stat
    /// lines their teams' identities. A failure just leaves the identities
    /// as `byteam` ships them.
    func loadFBSStandings(year: Int) async {
        guard league == .collegeFootball, standingsByYear[year] == nil,
              !standingsLoadingYears.contains(year) else { return }
        standingsLoadingYears.insert(year)
        defer { standingsLoadingYears.remove(year) }
        let current = SeasonYear.year(for: league)
        guard let standings = try? await DataProvider.makeClient(league: league)
            .conferenceStandings(year: year == current ? nil : year, division: .fbs),
              !Task.isCancelled else { return }
        standingsByYear[year] = standings
    }
}
