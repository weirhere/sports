import SwiftUI

/// One conference's home, on the TeamPage template (Andy's call,
/// 2026-08-25): hero header with the cluster top-right, standings as a
/// card on the recessed surface. Conferences ship no ESPN color, so the
/// hero is the template's monochrome variant. Standings stay in the
/// provider's order (seed-backed — never re-sorted here).
struct ConferencePage: View {
    let destination: ConferenceDestination

    /// Seasons fetched this visit, keyed by year — flipping back to a seen
    /// season costs nothing (TeamPage's caching pattern).
    @State private var standingsByYear: [Int: ConferenceStandings] = [:]
    @State private var selectedYear = CFBSeason.year()
    @State private var loadingYears: Set<Int> = []
    @State private var failedYears: Set<Int> = []

    private let client: any ScoresProviding = DataProvider.makeClient()

    private var standings: ConferenceStandings? { standingsByYear[selectedYear] }
    private var isLoading: Bool { loadingYears.contains(selectedYear) }
    private var showsError: Bool { failedYears.contains(selectedYear) }

    /// Newest first, floored at 2014 — the CFP era, matching the Scores and
    /// TeamPage selectors.
    private var availableSeasons: [Int] {
        Array(stride(from: CFBSeason.year(), through: 2014, by: -1))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    standingsCard
                }
            }
            // The anchor scroll: a push from a TeamPage lands with the
            // team's own row in view, FotMob's table pattern.
            .onChange(of: standings) { _, loaded in
                guard let target = destination.highlightTeamId,
                      loaded?.entries.contains(where: { $0.team.id == target }) == true else { return }
                proxy.scrollTo(target, anchor: .center)
            }
        }
        .background(Color.bgRecessed)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await load(year: selectedYear) }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.md) {
                Spacer()
                SeasonMenuChip(current: selectedYear, seasons: availableSeasons,
                               onSelect: { select(year: $0) })
                ConferenceFollowPill(conferenceId: destination.conferenceId)
            }
            .padding(.horizontal, Spacing.lg)

            HStack(spacing: Spacing.md) {
                LogoImage(url: Conference.logoURL(for: destination.conferenceId))
                    .frame(width: 44, height: 44)
                    // Navy marks (Big Ten, ACC) vanish on black; the backing
                    // disc is chrome, not color, so the budget holds.
                    .background(Circle().fill(Color.logoBacking).padding(-6))
                    .padding(6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.name)
                        .font(.heroTitle)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let count = standings?.entries.count, count > 0 {
                        Text("\(count) teams")
                            .font(.chipEmphasis)
                            .foregroundStyle(.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgPrimary)
    }

    // MARK: - Standings

    private var standingsCard: some View {
        VStack(spacing: 0) {
            CardHeader(title: "Standings")
            if let entries = standings?.entries, !entries.isEmpty {
                StandingsList(
                    entries: entries,
                    highlightTeamId: destination.highlightTeamId,
                    showsTitleGameCut: Conference.titleGameIsTopTwo(id: destination.conferenceId,
                                                                    year: selectedYear)
                )
            } else if isLoading {
                ProgressView().padding(.vertical, Spacing.xl)
            } else if showsError {
                VStack(spacing: Spacing.sm) {
                    Text("Couldn't load standings.")
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    Button("Retry") {
                        Task { await load(year: selectedYear, force: true) }
                    }
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
                }
                .padding(.vertical, Spacing.xl)
            } else {
                // ESPN's offseason standings can come back empty (Sun Belt
                // did), and an old season can omit a young conference.
                Text("Standings TBA")
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
        .padding(Spacing.sm)
    }

    // MARK: - Loads

    private func select(year: Int) {
        guard year != selectedYear else { return }
        selectedYear = year
        Task { await load(year: year) }
    }

    private func load(year: Int, force: Bool = false) async {
        guard standingsByYear[year] == nil || force else { return }
        guard !loadingYears.contains(year) else { return }
        loadingYears.insert(year)
        defer { loadingYears.remove(year) }
        do {
            // Nil for the current season keeps the shipped request shape;
            // an explicit past year is scoped with `season={year}`.
            let all = try await client.conferenceStandings(
                year: year == CFBSeason.year() ? nil : year)
            standingsByYear[year] = all.first { $0.id == destination.conferenceId }
                ?? ConferenceStandings(id: destination.conferenceId,
                                       name: destination.name, entries: [])
            failedYears.remove(year)
        } catch {
            failedYears.insert(year)
        }
    }
}
