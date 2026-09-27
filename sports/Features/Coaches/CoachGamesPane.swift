import SwiftUI

/// The Games tab: a season chip over the seasons the coach held the job,
/// and that season's schedule for the team they coached.
///
/// **The team's season, not strictly the coach's games.** ESPN keeps no per-coach
/// game list; it keeps the coach's season and the team's schedule. The two
/// are the same thing except in a season with a mid-year change, where the
/// schedule also holds the games the other coach ran. The card's title
/// carries the coach's own record for the season, which is what tells them apart.
struct CoachGamesPane: View {
    let seasons: [CoachSeason]
    let teams: [String: CoachClient.TeamLabel]
    let league: League

    /// Our opening-year axis; nil shows the newest season.
    @State private var selectedYear: Int?
    @State private var schedules: [String: [Game]] = [:]
    @State private var failed: Set<String> = []

    private var season: CoachSeason? {
        guard let year = selectedYear ?? seasons.first?.year else { return nil }
        return seasons.first { $0.year == year }
    }

    var body: some View {
        if let season {
            let years = seasons.map(\.year).reduce(into: [Int]()) { if !$0.contains($1) { $0.append($1) } }
            if years.count > 1 {
                HStack {
                    SeasonMenuChip(current: season.year, seasons: years, league: league) {
                        selectedYear = $0
                    }
                    Spacer()
                }
            }
            scheduleCard(season)
                .task(id: season.id) { await load(season) }
        } else {
            StatusMessage(text: "No games on record.")
                .cardSurface()
        }
    }

    private func scheduleCard(_ season: CoachSeason) -> some View {
        VStack(spacing: 0) {
            TeamScheduleSection(
                teamId: season.teamId,
                title: title(season),
                games: schedules[season.id] ?? [],
                isLoading: schedules[season.id] == nil && !failed.contains(season.id),
                showsError: failed.contains(season.id),
                onRetry: { Task { await load(season) } }
            )
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    /// "Tampa Bay Buccaneers · 8-9": the team, and the coach's record for the season.
    private func title(_ season: CoachSeason) -> String {
        let team = teams[season.teamId]?.name ?? league.seasonLabel(season.year)
        guard let record = season.record else { return team }
        return "\(team) · \(record.summary)"
    }

    private func load(_ season: CoachSeason) async {
        guard schedules[season.id] == nil else { return }
        failed.remove(season.id)
        let client = DataProvider.makeClient(league: league)
        do {
            let schedule = try await client.teamSchedule(teamId: season.teamId, year: season.year)
            schedules[season.id] = schedule.games
        } catch {
            failed.insert(season.id)
        }
    }
}
