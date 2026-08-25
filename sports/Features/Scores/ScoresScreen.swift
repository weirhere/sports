import SwiftUI

/// The product: one screen answering "what's the state of college football
/// right now" in one thumb, one scroll. Week strip → section stack.
struct ScoresScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState
    @Environment(Router.self) private var router
    // Owned by RootView so the search cover shares the loaded week and
    // polling follows the scene, not this tab.
    @Environment(ScoreboardStore.self) private var store

    // NavigationPath, not [Game]: the stack pushes Team (game detail's
    // header links) and ConferenceDestination (section headers' standings
    // links) too, and a typed path can't hold them all.
    @State private var path = NavigationPath()
    @State private var refreshCount = 0
    @State private var pinchHandled = false
    // Which edge the incoming week's content pushes from, set before every
    // week change so the slide matches the strip's spatial order.
    @State private var weekSlideEdge: Edge = .trailing
    // Nil until the first user week change: the initial load and season
    // switches have no meaningful direction, so they must not slide.
    @State private var weekSlideAnimation: Animation?

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScoresHeader(
                    seasonYear: store.seasonYear,
                    seasons: store.availableSeasons,
                    byDate: uiState.scoresGrouping == .date,
                    onSelectSeason: { year in
                        weekSlideAnimation = nil
                        Task { await store.select(season: year) }
                    },
                    onToggleGrouping: {
                        withAnimation {
                            uiState.scoresGrouping = uiState.scoresGrouping == .date ? .conference : .date
                        }
                    }
                )
                WeekStrip(weeks: store.weeks, selectedId: store.selectedWeek?.id) { week in
                    select(week: week)
                }
                if store.hasLiveGames || store.liveOnly {
                    liveChipRow
                }
                Divider().overlay(Color.divider)
                if store.lastError != nil, !sections.isEmpty {
                    refreshErrorBanner
                }
                // The ZStack scopes the push transition: the content's
                // identity is the selected week, so a week change slides the
                // old slate out and the new one in from `weekSlideEdge`.
                ZStack {
                    content
                        .id(store.selectedWeek?.id)
                        .transition(.push(from: weekSlideEdge))
                }
                .animation(weekSlideAnimation, value: store.selectedWeek?.id)
                // Horizontal counterpart to the week strip: swipe left for
                // the next week, right for the previous. Simultaneous so
                // vertical scrolling and the pinch gesture are unaffected;
                // attached here (not inside `content`) so the empty week
                // and error states are swipeable too — the states where
                // leaving the week matters most.
                .simultaneousGesture(weekSwipeGesture)
            }
            .background(Color.bgPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Game.self) { game in
                GameDetailScreen(game: game)
            }
            .navigationDestination(for: ConferenceDestination.self) { destination in
                ConferencePage(destination: destination)
            }
            .navigationDestination(for: Team.self) { team in
                TeamPage(team: team)
            }
        }
        // onAppear mirrors TeamsScreen: lazy tab content means an intent can
        // predate the onChange observers. Scores is the launch tab, so this
        // mostly matters after the tab's view is torn down and recreated.
        .onAppear { resolvePendingGame() }
        .onChange(of: router.pendingGameId) { _, _ in resolvePendingGame() }
        .onChange(of: store.games) { _, _ in resolvePendingGame() }
    }

    private var sections: [GameSection] {
        store.sections(followingIds: following.teamIds,
                       followedConferenceIds: following.conferenceIds,
                       grouping: uiState.scoresGrouping)
    }

    /// Every user week change funnels through here so chip taps and swipes
    /// share one direction rule: content slides the way the strip moves.
    private func select(week: WeekSlot) {
        guard week.id != store.selectedWeek?.id else { return }
        if let from = store.weeks.firstIndex(where: { $0.id == store.selectedWeek?.id }),
           let to = store.weeks.firstIndex(where: { $0.id == week.id }) {
            weekSlideEdge = to > from ? .trailing : .leading
        }
        weekSlideAnimation = .default
        Task { await store.select(week: week) }
    }

    /// A gesture-only accelerator, like the pinch: the week strip keeps a
    /// tappable chip per week, so nothing is swipe-gated for VoiceOver or
    /// switch users. The dominance check keeps diagonal scroll flicks from
    /// changing the week; no haptic (the budget of three holds).
    private var weekSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 25)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 50, abs(dx) > abs(dy) * 1.5 else { return }
                guard let target = store.adjacentWeek(offset: dx < 0 ? 1 : -1) else { return }
                select(week: target)
            }
    }

    /// Lands a widget/notification tap on its game once the current week is
    /// loaded. The widget only links current-week games, so `store.games`
    /// is the complete search space; an id that isn't there (week rolled
    /// over) degrades to landing on Scores.
    private func resolvePendingGame() {
        guard let pendingId = router.pendingGameId,
              let game = store.games.first(where: { $0.id == pendingId }) else { return }
        router.pendingGameId = nil
        path = NavigationPath([game])
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
                    // The Following slot's empty state: following nobody
                    // renders the follow prompt where the section would be.
                    if !following.followsAnyone, !uiState.followPromptDismissed {
                        FollowPromptCard()
                            .cardSurface()
                    }
                    ForEach(sections) { section in
                        SectionAccordion(
                            section: section,
                            isExpanded: uiState.isExpanded(section.id),
                            onToggle: { withAnimation { uiState.toggle(section.id) } },
                            onOpenStandings: section.conferenceId.map { id in
                                { path.append(ConferenceDestination(conferenceId: id,
                                                                    name: section.title)) }
                            }
                        )
                        .cardSurface()
                    }
                }
                .padding(Spacing.sm)
            }
            .background(Color.bgRecessed)
            .refreshable {
                await store.refresh()
                refreshCount += 1
            }
            .sensoryFeedback(.success, trigger: refreshCount)
            // FotMob's gesture: pinch in collapses every section on screen,
            // pinch out opens them all. Fires once per pinch at the
            // threshold crossing; simultaneous so scroll, pull-to-refresh,
            // and header taps are unaffected.
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        guard !pinchHandled else { return }
                        if value.magnification < 0.8 {
                            pinchHandled = true
                            withAnimation { uiState.collapseAll(sections.map(\.id)) }
                        } else if value.magnification > 1.25 {
                            pinchHandled = true
                            withAnimation { uiState.expandAll(sections.map(\.id)) }
                        }
                    }
                    .onEnded { _ in pinchHandled = false }
            )
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
            // The stack is mostly empty space, which doesn't hit-test;
            // without this, the week swipe dies exactly where it's most
            // needed — on an empty week.
            .contentShape(Rectangle())
        }
    }

    /// The next week-slot start still in the future — the offseason
    /// countdown target.
    private var nextKickoff: Date? {
        store.weeks.compactMap(\.startDate).filter { $0 > .now }.min()
    }
}
