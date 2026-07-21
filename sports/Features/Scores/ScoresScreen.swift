import SwiftUI

/// The product: one screen answering "what's the state of college football
/// right now" in one thumb, one scroll. Week strip → chips → section stack.
struct ScoresScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState
    @Environment(\.scenePhase) private var scenePhase

    @State private var store = ScoreboardStore(client: ESPNClient())

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeekStrip(weeks: store.weeks, selectedId: store.selectedWeek?.id) { week in
                    Task { await store.select(week: week) }
                }
                ConferenceChips(
                    sections: sections,
                    liveOnly: store.liveOnly,
                    hasLiveGames: store.hasLiveGames,
                    onToggleLive: { withAnimation { store.liveOnly.toggle() } },
                    onJump: { section in jumpTarget = section.id }
                )
                Divider().overlay(Color.divider)
                content
            }
            .background(Color.bgPrimary)
            .toolbar(.hidden, for: .navigationBar)
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

    @State private var jumpTarget: String?

    private var sections: [GameSection] {
        store.sections(followingIds: following.teamIds)
    }

    @ViewBuilder
    private var content: some View {
        let sections = self.sections
        if sections.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sections) { section in
                            SectionAccordion(
                                section: section,
                                isExpanded: uiState.isExpanded(section.id),
                                onToggle: { withAnimation { uiState.toggle(section.id) } }
                            )
                            .id(section.id)
                        }
                    }
                }
                .refreshable { await store.refresh() }
                .onChange(of: jumpTarget) { _, target in
                    guard let target else { return }
                    uiState.expand(target)
                    withAnimation { proxy.scrollTo(target, anchor: .top) }
                    jumpTarget = nil
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            if store.isLoading {
                ProgressView()
            } else if let error = store.lastError {
                Text(error)
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
                Button("Retry") {
                    Task { await store.refresh() }
                }
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            } else {
                Text(store.liveOnly ? "No live games right now" : "No games this week")
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
