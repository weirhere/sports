import SwiftUI

/// One conference's home: identity, follow, and its standings in the
/// provider's order (ESPN's encodes tiebreakers — never re-sorted here).
struct ConferencePage: View {
    let destination: ConferenceDestination

    /// Seasons fetched this visit, keyed by year — flipping back to a seen
    /// season costs nothing (TeamPage's caching pattern).
    @State private var standingsByYear: [Int: ConferenceStandings] = [:]
    @State private var selectedYear = CFBSeason.year()
    @State private var loadingYears: Set<Int> = []
    @State private var failedYears: Set<Int> = []

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // Mirrors ConferenceStandingRow's column width so captions align with
    // the numbers beneath them.
    @ScaledMetric(relativeTo: .subheadline) private var recordWidth: CGFloat = 44

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
                    header
                    Divider().overlay(Color.divider)
                    standingsSection
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
        .background(Color.bgPrimary)
        .navigationTitle(destination.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load(year: selectedYear) }
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            LogoImage(url: Conference.logoURL(for: destination.conferenceId))
                .frame(width: 64, height: 64)
                // Navy marks (Big Ten, ACC) vanish on black; the backing
                // disc is chrome, not color, so the budget holds.
                .background(Circle().fill(Color.logoBacking).padding(-8))
                .padding(8)
            Text(destination.name)
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            ConferenceFollowPill(conferenceId: destination.conferenceId)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    @ViewBuilder
    private var standingsSection: some View {
        // The header (and its season chip) stays mounted through every
        // state, so an empty or failed season never strands the user there.
        HStack(spacing: Spacing.sm) {
            Text("STANDINGS")
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
            Spacer()
            SeasonMenuChip(current: selectedYear, seasons: availableSeasons,
                           onSelect: { select(year: $0) })
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        if let entries = standings?.entries, !entries.isEmpty {
            // At accessibility sizes the rows stack their records onto a
            // labeled line, so the column captions would caption nothing.
            if !dynamicTypeSize.isAccessibilitySize {
                columnHeader
            }
            ForEach(entries) { standing in
                NavigationLink(value: standing.team) {
                    ConferenceStandingRow(standing: standing)
                }
                .buttonStyle(.plain)
                // The pushing team's row reads as "you are here".
                .background(standing.team.id == destination.highlightTeamId
                            ? Color.bgHeader : Color.clear)
                .id(standing.id)
                if standing.id != entries.last?.id {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                }
            }
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
                .padding(.vertical, Spacing.xl)
        }
    }

    /// Column captions for the two record columns. Visual-only — each row
    /// speaks its records as a sentence, so VO skips this line.
    private var columnHeader: some View {
        HStack(spacing: Spacing.md) {
            Text("TEAM")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CONF")
                .frame(minWidth: recordWidth, alignment: .trailing)
            Text("OVR")
                .frame(minWidth: recordWidth, alignment: .trailing)
        }
        .font(.meta)
        .foregroundStyle(.textSecondary)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xs)
        .accessibilityHidden(true)
    }

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
