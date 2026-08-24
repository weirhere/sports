import SwiftUI

/// One team's home: identity, record, follow, and a schedule for any
/// season back to the CFP era.
struct TeamPage: View {
    let team: Team

    /// Optional form: previews/tests without RootView's environment degrade
    /// to the pushed value instead of trapping.
    @Environment(TeamDirectoryStore.self) private var directory: TeamDirectoryStore?

    /// Seasons fetched this visit, keyed by year — flipping back to a
    /// seen season costs ESPN nothing (each season is two requests).
    @State private var schedules: [Int: TeamSchedule] = [:]
    /// Nil until the first load lands; set from the payload's year so the
    /// chip label can't drift from the data (the current-season fetch may
    /// fall back a season while the next one is unpublished).
    @State private var selectedYear: Int?
    /// Where the first load landed. The share always describes this
    /// season, whatever the chip is showing.
    @State private var currentSeasonYear: Int?
    @State private var loadingYears: Set<Int> = []
    @State private var failedYears: Set<Int> = []
    @State private var initialLoading = false
    @State private var initialFailed = false

    private let client: any ScoresProviding = DataProvider.makeClient()

    private var schedule: TeamSchedule? {
        selectedYear.flatMap { schedules[$0] }
    }

    private var currentSchedule: TeamSchedule? {
        currentSeasonYear.flatMap { schedules[$0] }
    }

    /// Newest first, floored at 2014 — the CFP era, matching the Scores
    /// header's selector.
    private var availableSeasons: [Int] {
        Array(stride(from: CFBSeason.year(), through: 2014, by: -1))
    }

    /// The selected season's payload wins (groups is season-scoped, so a
    /// realignment year reads correctly under the season chip), then the
    /// pushed value (instant, pre-fetch), then the team directory (covers
    /// Rankings/game-detail entry paths that push no id).
    private var resolvedConferenceId: Int? {
        schedule?.team?.conferenceId
            ?? team.conferenceId
            ?? directory?.allTeams.first(where: { $0.id == team.id })?.conferenceId
    }

    private var isLoadingSelected: Bool {
        guard let selectedYear else { return initialLoading }
        return loadingYears.contains(selectedYear)
    }

    private var showsErrorForSelected: Bool {
        guard let selectedYear else { return initialFailed }
        return failedYears.contains(selectedYear)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider().overlay(Color.divider)
                TeamScheduleSection(
                    teamId: team.id,
                    games: schedule?.games ?? [],
                    selectedYear: selectedYear,
                    seasons: availableSeasons,
                    isLoading: isLoadingSelected,
                    showsError: showsErrorForSelected,
                    onSelectYear: { select(year: $0) },
                    onRetry: { Task { await retry() } }
                )
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle(team.location)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: team.shareText(schedule: currentSchedule)) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.textPrimary)
                }
                .accessibilityLabel("Share this team")
            }
        }
        .task { await loadInitial() }
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            LogoImage(url: team.logoURL)
                .frame(width: 64, height: 64)
            Text(team.displayName ?? team.location)
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            // A past season's record derives from its final results —
            // the provider's summary only describes the current season
            // (the mapper nils it otherwise).
            if let record = schedule?.record ?? schedule?.derivedRecord {
                Text(record)
                    .font(.metaEmphasis)
                    .foregroundStyle(.textPrimary)
            }
            // A placement next to 0-0 is false precision — ESPN carries
            // last season's standing until games are played — so the line
            // shows the bare conference then; the link itself stays.
            TeamConferenceLink(
                conferenceId: resolvedConferenceId,
                standing: schedule?.record == "0-0" ? nil : schedule?.standing
            )
            followPill
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    private var followPill: some View {
        HStack(spacing: Spacing.sm) {
            FollowPill(teamId: team.id)
            NotificationBell()
        }
    }

    private func loadInitial() async {
        guard selectedYear == nil, !initialLoading else { return }
        initialLoading = true
        defer { initialLoading = false }
        do {
            let loaded = try await client.teamSchedule(teamId: team.id)
            // Register the result under the year it really is, so
            // explicitly re-picking the fallback season is a cache hit.
            let year = loaded.year ?? CFBSeason.year()
            schedules[year] = loaded
            currentSeasonYear = year
            selectedYear = year
            initialFailed = false
        } catch {
            initialFailed = true
        }
    }

    private func select(year: Int) {
        guard year != selectedYear else { return }
        selectedYear = year
        guard schedules[year] == nil, !loadingYears.contains(year) else { return }
        Task { await load(year: year) }
    }

    private func load(year: Int) async {
        loadingYears.insert(year)
        defer { loadingYears.remove(year) }
        do {
            schedules[year] = try await client.teamSchedule(teamId: team.id, year: year)
            failedYears.remove(year)
        } catch {
            failedYears.insert(year)
        }
    }

    private func retry() async {
        if let selectedYear {
            await load(year: selectedYear)
        } else {
            await loadInitial()
        }
    }
}
