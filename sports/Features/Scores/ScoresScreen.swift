import SwiftUI

/// The product: one screen answering "what's the state of college football
/// right now" in one thumb, one scroll. Week strip → section stack.
struct ScoresScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState
    @Environment(\.scenePhase) private var scenePhase

    @State private var store = ScoreboardStore(client: ESPNClient())

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScoresHeader(
                    seasonYear: store.seasonYear,
                    seasons: store.availableSeasons,
                    byDate: uiState.scoresGrouping == .date,
                    onSelectSeason: { year in Task { await store.select(season: year) } },
                    onToggleGrouping: {
                        withAnimation {
                            uiState.scoresGrouping = uiState.scoresGrouping == .date ? .conference : .date
                        }
                    }
                )
                WeekStrip(weeks: store.weeks, selectedId: store.selectedWeek?.id) { week in
                    Task { await store.select(week: week) }
                }
                if store.hasLiveGames || store.liveOnly {
                    liveChipRow
                }
                Divider().overlay(Color.divider)
                if store.lastError != nil, !sections.isEmpty {
                    refreshErrorBanner
                }
                content
            }
            .background(Color.bgPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Game.self) { game in
                GameDetailScreen(game: game)
            }
        }
        .task { await store.loadInitial() }
        .onChange(of: scenePhase) { _, phase in
            // Polite guest: poll only while foregrounded.
            if phase == .active {
                store.startPollingIfNeeded()
            } else {
                store.stopPolling()
            }
        }
    }

    private var sections: [GameSection] {
        store.sections(followingIds: following.teamIds, grouping: uiState.scoresGrouping)
    }

    private var liveChipRow: some View {
        HStack {
            LiveFilterChip(
                liveOnly: store.liveOnly,
                onToggle: { withAnimation { store.liveOnly.toggle() } }
            )
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    @ViewBuilder
    private var content: some View {
        let sections = self.sections
        if sections.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(sections) { section in
                        SectionAccordion(
                            section: section,
                            isExpanded: uiState.isExpanded(section.id),
                            onToggle: { withAnimation { uiState.toggle(section.id) } }
                        )
                        .cardSurface()
                    }
                }
                .padding(Spacing.sm)
            }
            .background(Color.bgRecessed)
            .refreshable { await store.refresh() }
        }
    }

    /// Quiet one-line banner when a refresh fails but last-good data is
    /// still on screen.
    private var refreshErrorBanner: some View {
        HStack(spacing: Spacing.sm) {
            Text("Couldn't refresh")
                .font(.meta)
                .foregroundStyle(.textSecondary)
            Button("Retry") {
                Task { await store.refresh() }
            }
            .font(.metaEmphasis)
            .foregroundStyle(.textPrimary)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs)
        .background(Color.bgElevated)
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.isLoading {
            ScrollView { SkeletonRows() }
        } else {
            VStack(spacing: Spacing.md) {
                Spacer()
                if let error = store.lastError {
                    Text(error)
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    Button("Retry") {
                        Task { await store.refresh() }
                    }
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
                } else if store.liveOnly {
                    Text("No live games right now")
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                } else {
                    Text("No games this week")
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    if let kickoff = nextKickoff {
                        Text("Season kicks off \(kickoff.formatted(.dateTime.weekday(.wide).month().day()))")
                            .font(.metaEmphasis)
                            .foregroundStyle(.textPrimary)
                        Text(kickoff, style: .relative)
                            .font(.meta)
                            .foregroundStyle(.textSecondary)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The next week-slot start still in the future — the offseason
    /// countdown target.
    private var nextKickoff: Date? {
        store.weeks.compactMap(\.startDate).filter { $0 > .now }.min()
    }
}
