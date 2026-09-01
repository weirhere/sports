import SwiftUI
import os

/// The product: one screen answering "what's the state of college football
/// right now" in one thumb, one scroll. Week strip → section stack.
struct ScoresScreen: View {
    /// Forensics for the self-popping live detail (BACKLOG E5, found
    /// 2026-08-29): a pop through the path binding logs a count change; a
    /// pop with no count change means the screen's @State was rebuilt —
    /// two different bugs, distinguishable only if we log both.
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "scoresnav")
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
    // The interactive week swipe (Andy's ask, 2026-08-25: content moves
    // the moment the thumb does, not after it lifts). The content tracks
    // the finger; past the commit threshold it settles off-screen and the
    // adjacent week takes over with no push transition of its own.
    @State private var dragOffset: CGFloat = 0
    @State private var dragAxis: DragAxis?
    @State private var paneWidth: CGFloat = 393
    @State private var showsFilterSheet = false

    private enum DragAxis { case horizontal, vertical }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScoresHeader(
                    liveOnly: uiState.liveOnly,
                    scoreFilter: uiState.scoreFilter,
                    pastSeasonYear: pastSeasonYear,
                    onToggleLive: { toggleLive() },
                    onTapFilter: { showsFilterSheet = true }
                )
                WeekStrip(weeks: store.weeks, selectedId: store.selectedWeek?.id) { week in
                    select(week: week)
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
                        .offset(x: dragOffset)
                    // The adjacent week rides in with the finger — its
                    // real slate when the prefetch has landed (FotMob's
                    // mid-swipe preview, Andy 2026-08-31), the skeleton
                    // until then. Either way the commit handoff is
                    // seamless: the cache seeds the real week too.
                    if dragOffset != 0,
                       let target = store.adjacentWeek(offset: dragOffset < 0 ? 1 : -1) {
                        previewPane(for: target)
                            .offset(x: dragOffset + (dragOffset < 0 ? paneWidth : -paneWidth))
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.onAppear { paneWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { _, width in paneWidth = width }
                    }
                )
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
        .sheet(isPresented: $showsFilterSheet) {
            ScoreFilterSheet(
                current: uiState.scoreFilter,
                grouping: uiState.scoresGrouping,
                seasonYear: store.seasonYear,
                seasons: store.availableSeasons,
                onSelect: { selection in
                    withAnimation { uiState.scoreFilter = selection }
                },
                onSetGrouping: { grouping in
                    withAnimation { uiState.scoresGrouping = grouping }
                },
                onSelectSeason: { year in
                    weekSlideAnimation = nil
                    Task { await store.select(season: year) }
                }
            )
        }
        // onAppear mirrors TeamsScreen: lazy tab content means an intent can
        // predate the onChange observers. Scores is the launch tab, so this
        // mostly matters after the tab's view is torn down and recreated.
        .onAppear {
            Self.logger.info("scores appeared, path depth \(path.count)")
            resolvePendingGame()
        }
        .onChange(of: path.count) { old, new in
            Self.logger.info("scores path depth \(old) -> \(new)")
        }
        // The slate's divisions follow the user's choices: FBS always, FCS
        // only while an FCS conference is filtered to or followed (E8 scope
        // (b)). `select(divisions:)` refetches and clears the week cache,
        // and no-ops when nothing changed — so these fire freely.
        .task(id: neededDivisions) { await store.select(divisions: neededDivisions) }
        .onChange(of: router.pendingGameId) { _, _ in resolvePendingGame() }
        .onChange(of: store.games) { _, _ in resolvePendingGame() }
        // The drag-commit handoff: the new week takes the screen the moment
        // its id lands, so the settled offset snaps home with it.
        .onChange(of: store.selectedWeek?.id) { _, _ in dragOffset = 0 }
    }

    private var neededDivisions: Set<Conference.Division> {
        ScoreboardStore.divisions(filter: uiState.scoreFilter,
                                  followedConferenceIds: following.conferenceIds)
    }

    private var sections: [GameSection] {
        store.sections(followingIds: following.teamIds,
                       followedConferenceIds: following.conferenceIds,
                       grouping: uiState.scoresGrouping,
                       liveOnly: uiState.liveOnly,
                       filter: uiState.scoreFilter)
    }

    /// The selected season when browsing the past — what the funnel chip
    /// surfaces so a 2019 slate is never mistaken for this week.
    private var pastSeasonYear: Int? {
        guard let year = store.seasonYear, year != store.currentSeasonYear else { return nil }
        return year
    }

    /// Turning the Live filter on goes to where live games are — the
    /// current week (Andy, 2026-08-29): filtering a future week to
    /// nothing answers the wrong question. Within the season the jump
    /// slides like a chip tap; a past season resets with no direction
    /// (season switches never slide). Turning it off stays put.
    private func toggleLive() {
        withAnimation { uiState.liveOnly.toggle() }
        guard uiState.liveOnly else { return }
        if store.seasonYear != store.currentSeasonYear {
            weekSlideAnimation = nil
            Task { await store.selectCurrentWeek() }
        } else if let home = store.currentWeekSlot, home.id != store.selectedWeek?.id {
            select(week: home)
        }
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
    /// switch users. The axis locks on first movement so vertical scroll
    /// flicks never jiggle the week; horizontal drags move the content
    /// immediately, commit on distance or flick velocity, and season ends
    /// resist instead of paging. No haptic (the budget of three holds).
    private var weekSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if dragAxis == nil, abs(dx) > 10 || abs(dy) > 10 {
                    dragAxis = abs(dx) > abs(dy) * 1.5 ? .horizontal : .vertical
                    // Idempotent backstop: the neighbors usually warmed on
                    // settle, but a failed prefetch gets another chance
                    // the moment a swipe actually starts.
                    if dragAxis == .horizontal { store.prefetchAdjacentWeeks() }
                }
                guard dragAxis == .horizontal else { return }
                let hasTarget = store.adjacentWeek(offset: dx < 0 ? 1 : -1) != nil
                dragOffset = hasTarget ? dx : dx * 0.25
            }
            .onEnded { value in
                defer { dragAxis = nil }
                guard dragAxis == .horizontal else { return }
                let dx = value.translation.width
                let flick = value.predictedEndTranslation.width
                // Commit on distance, or on a flick that keeps the drag's
                // direction; a flick back toward the origin cancels.
                let sameDirection = (dx < 0) == (flick < 0)
                let commits = abs(dx) > paneWidth * 0.35
                    || (sameDirection && abs(flick) > paneWidth * 0.6)
                guard commits,
                      let target = store.adjacentWeek(offset: dx < 0 ? 1 : -1) else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        dragOffset = 0
                    }
                    return
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.95),
                              completionCriteria: .logicallyComplete) {
                    dragOffset = dx < 0 ? -paneWidth : paneWidth
                } completion: {
                    // The push transition is the chip taps' mechanism; the
                    // drag already animated, so the id swap is instant. The
                    // offset resets when the week actually changes (see
                    // onChange below), so the skeleton pane covers the
                    // handoff frame.
                    weekSlideAnimation = nil
                    Task { await store.select(week: target) }
                }
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

    @ViewBuilder
    private var content: some View {
        let sections = self.sections
        if sections.isEmpty {
            emptyState
        } else {
            ScrollView {
                // pinnedViews only bites in the date grouping, where each
                // accordion emits a Section whose day header sticks to the
                // top while its games scroll (Andy, 2026-08-25).
                // Date mode runs spacing 0 so a pinned header sits flush on
                // its rows; each section carries its own gap to the next.
                LazyVStack(spacing: uiState.scoresGrouping == .date ? 0 : Spacing.sm,
                           pinnedViews: [.sectionHeaders]) {
                    // The Following slot's empty state: following nobody
                    // renders the follow prompt where the section would be.
                    if !following.followsAnyone, !uiState.followPromptDismissed {
                        FollowPromptCard()
                            .cardSurface()
                            .padding(.bottom, uiState.scoresGrouping == .date ? Spacing.sm : 0)
                    }
                    ForEach(sections) { section in
                        if uiState.scoresGrouping == .date {
                            SectionAccordion(
                                section: section,
                                isExpanded: uiState.isExpanded(section.id),
                                onToggle: { withAnimation { uiState.toggle(section.id) } },
                                onOpenStandings: section.conferenceId.map { id in
                                    { path.append(ConferenceDestination(conferenceId: id,
                                                                        name: section.title)) }
                                },
                                pinsHeader: true
                            )
                        } else {
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

    /// The incoming pane during a week drag. Render-only — no scrolling,
    /// tapping, refresh, or pinch until the commit makes it the real
    /// content — but it shares the accordions' expansion state, so the
    /// preview matches what lands.
    @ViewBuilder
    private func previewPane(for target: WeekSlot) -> some View {
        Group {
            if let cached = store.cachedGames(for: target) {
                let sections = store.sections(from: cached,
                                              followingIds: following.teamIds,
                                              followedConferenceIds: following.conferenceIds,
                                              grouping: uiState.scoresGrouping,
                                              liveOnly: uiState.liveOnly,
                                              filter: uiState.scoreFilter)
                if sections.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Spacer()
                        Text(uiState.liveOnly || uiState.scoreFilter != nil
                             ? narrowedEmptyMessage : "No games this week")
                            .font(.teamName)
                            .foregroundStyle(.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: uiState.scoresGrouping == .date ? 0 : Spacing.sm,
                                   pinnedViews: [.sectionHeaders]) {
                            ForEach(sections) { section in
                                if uiState.scoresGrouping == .date {
                                    SectionAccordion(section: section,
                                                     isExpanded: uiState.isExpanded(section.id),
                                                     onToggle: {},
                                                     pinsHeader: true)
                                } else {
                                    SectionAccordion(section: section,
                                                     isExpanded: uiState.isExpanded(section.id),
                                                     onToggle: {})
                                        .cardSurface()
                                }
                            }
                        }
                        .padding(Spacing.sm)
                    }
                }
            } else {
                ScrollView { SkeletonRows() }
            }
        }
        .scrollDisabled(true)
        .allowsHitTesting(false)
        .background(Color.bgRecessed)
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
                } else if uiState.liveOnly || uiState.scoreFilter != nil {
                    // The narrowed-slate empty state: name what's hiding
                    // the games, and offer the whole slate back. One
                    // button clears both filters — that's what its label
                    // promises.
                    Text(narrowedEmptyMessage)
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    Button("Show all games") {
                        withAnimation {
                            uiState.scoreFilter = nil
                            uiState.liveOnly = false
                        }
                    }
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
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

    /// What the narrowed-slate empty state says: live and the conference
    /// filter compose into one sentence.
    private var narrowedEmptyMessage: String {
        switch (uiState.liveOnly, uiState.scoreFilter) {
        case (true, let filter?): "No live \(filter.label) games right now"
        case (true, nil): "No live games right now"
        case (false, let filter?): "No \(filter.label) games this week"
        case (false, nil): ""
        }
    }

    /// The next week-slot start still in the future — the offseason
    /// countdown target.
    private var nextKickoff: Date? {
        store.weeks.compactMap(\.startDate).filter { $0 > .now }.min()
    }
}
