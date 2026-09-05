import SwiftUI
import os

/// The product: one screen answering "what's the state of the day" in one
/// thumb, one scroll. Day strip → Following → one accordion per league.
///
/// The league used to be a segmented control and the day a week (Andy,
/// 2026-09-05). Both changed for the same reason: a selector shows one
/// league at a time and has to grow a segment per sport, while a week strip
/// can only ever be honest about one league's calendar. Stacked league
/// accordions under a shared day cost one row each and scale to whatever
/// sport lands next.
struct ScoresScreen: View {
    /// Forensics for the self-popping live detail (BACKLOG E5, found
    /// 2026-08-29): a pop through the path binding logs a count change; a
    /// pop with no count change means the screen's @State was rebuilt —
    /// two different bugs, distinguishable only if we log both.
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "scoresnav")
    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState
    @Environment(Router.self) private var router
    // Owned by RootView so the search cover shares the loaded days and
    // polling follows the scene, not this tab.
    @Environment(LeagueScoreboards.self) private var scoreboards

    // NavigationPath, not [Game]: the stack pushes Team (game detail's
    // header links) and ConferenceDestination (a standings link from a
    // team page) too, and a typed path can't hold them all.
    @State private var path = NavigationPath()
    @State private var refreshCount = 0
    @State private var pinchHandled = false
    // Which edge the incoming day's content pushes from, set before every
    // day change so the slide matches the strip's spatial order.
    @State private var daySlideEdge: Edge = .trailing
    // Nil until the first user day change: the initial load and season
    // switches have no meaningful direction, so they must not slide.
    @State private var daySlideAnimation: Animation?
    // The interactive day swipe (Andy's ask, 2026-08-25, inherited from
    // the week swipe): content moves the moment the thumb does, not after
    // it lifts.
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
                DayStrip(days: scoreboards.days(),
                         selectedId: DayFormat.id(for: scoreboards.selectedDay),
                         today: .now) { day in
                    select(day: day)
                }
                Divider().overlay(Color.divider)
                if scoreboards.lastError != nil, !sections.isEmpty {
                    refreshErrorBanner
                }
                // The ZStack scopes the push transition: the content's
                // identity is the selected day, so a day change slides the
                // old slate out and the new one in from `daySlideEdge`.
                ZStack {
                    content
                        .id(DayFormat.id(for: scoreboards.selectedDay))
                        .transition(.push(from: daySlideEdge))
                        .offset(x: dragOffset)
                    // The adjacent day rides in with the finger. Its games
                    // are already in hand — every fetch is a five-day
                    // window, so both neighbours land in the same request
                    // the shown day did.
                    if dragOffset != 0,
                       let target = scoreboards.adjacentDay(offset: dragOffset < 0 ? 1 : -1) {
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
                .animation(daySlideAnimation, value: scoreboards.selectedDay)
                // Horizontal counterpart to the day strip: swipe left for
                // tomorrow, right for yesterday. Simultaneous so vertical
                // scrolling and the pinch gesture are unaffected; attached
                // here (not inside `content`) so the empty day and error
                // states are swipeable too — the states where leaving the
                // day matters most.
                .simultaneousGesture(daySwipeGesture)
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
                seasonYear: scoreboards.seasonYear,
                seasons: scoreboards.availableSeasons,
                onSelect: { selection in
                    withAnimation { uiState.scoreFilter = selection }
                },
                onSelectSeason: { year in
                    daySlideAnimation = nil
                    Task { await scoreboards.select(season: year) }
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
        // (b)). `select(divisions:)` refetches and no-ops when nothing
        // changed — so this fires freely.
        .task(id: neededDivisions) { await scoreboards.select(divisions: neededDivisions) }
        .onChange(of: router.pendingGameId) { _, _ in resolvePendingGame() }
        .onChange(of: scoreboards.selectedDay) { _, _ in
            dragOffset = 0
            resolvePendingGame()
        }
    }

    private var neededDivisions: Set<Conference.Division> {
        ScoreboardStore.divisions(filter: uiState.scoreFilter,
                                  followedConferenceIds: following.conferenceIds)
    }

    private var sections: [GameSection] {
        scoreboards.sections(followingIds: following.teamKeys,
                             followedConferenceIds: following.conferenceIds,
                             liveOnly: uiState.liveOnly,
                             filter: uiState.scoreFilter)
    }

    /// The selected season when browsing the past — what the funnel chip
    /// surfaces so a 2019 slate is never mistaken for this week.
    private var pastSeasonYear: Int? {
        scoreboards.seasonYear == scoreboards.currentSeasonYear ? nil : scoreboards.seasonYear
    }

    /// Turning the Live filter on goes to where live games are — today
    /// (Andy, 2026-08-29, when this was the current week): filtering a
    /// future day to nothing answers the wrong question. Turning it off
    /// stays put.
    private func toggleLive() {
        withAnimation { uiState.liveOnly.toggle() }
        guard uiState.liveOnly, !scoreboards.isOnToday else { return }
        daySlideAnimation = nil
        Task { await scoreboards.selectToday() }
    }

    /// Every user day change funnels through here so chip taps and swipes
    /// share one direction rule: content slides the way the strip moves.
    private func select(day: Date) {
        let day = Calendar.current.startOfDay(for: day)
        guard day != scoreboards.selectedDay else { return }
        daySlideEdge = day > scoreboards.selectedDay ? .trailing : .leading
        daySlideAnimation = .default
        Task { await scoreboards.select(day: day) }
    }

    /// A gesture-only accelerator, like the pinch: the day strip keeps a
    /// tappable chip per day, so nothing is swipe-gated for VoiceOver or
    /// switch users. The axis locks on first movement so vertical scroll
    /// flicks never jiggle the day; horizontal drags move the content
    /// immediately, commit on distance or flick velocity, and season ends
    /// resist instead of paging. No haptic (the budget of three holds).
    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if dragAxis == nil, abs(dx) > 10 || abs(dy) > 10 {
                    dragAxis = abs(dx) > abs(dy) * 1.5 ? .horizontal : .vertical
                }
                guard dragAxis == .horizontal else { return }
                let hasTarget = scoreboards.adjacentDay(offset: dx < 0 ? 1 : -1) != nil
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
                      let target = scoreboards.adjacentDay(offset: dx < 0 ? 1 : -1) else {
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
                    // offset resets when the day actually changes (see
                    // onChange above), so the preview covers the handoff.
                    daySlideAnimation = nil
                    Task { await scoreboards.select(day: target) }
                }
            }
    }

    /// Lands a widget/notification tap on its game. The search space is
    /// every day currently in memory across every league; an id that isn't
    /// there degrades to landing on Scores.
    private func resolvePendingGame() {
        guard let pendingId = router.pendingGameId,
              let game = scoreboards.game(id: pendingId) else { return }
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
                            onToggle: { withAnimation { uiState.toggle(section.id) } }
                        )
                        .cardSurface()
                    }
                }
                .padding(Spacing.sm)
            }
            .background(Color.bgRecessed)
            .refreshable {
                await scoreboards.refresh()
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

    /// The incoming pane during a day drag. Render-only — no scrolling,
    /// tapping, refresh, or pinch until the commit makes it the real
    /// content — but it shares the accordions' expansion state, so the
    /// preview matches what lands.
    @ViewBuilder
    private func previewPane(for target: Date) -> some View {
        let sections = scoreboards.sections(day: target,
                                            followingIds: following.teamKeys,
                                            followedConferenceIds: following.conferenceIds,
                                            liveOnly: uiState.liveOnly,
                                            filter: uiState.scoreFilter)
        Group {
            if sections.isEmpty {
                VStack(spacing: Spacing.md) {
                    Spacer()
                    Text(emptyMessage(for: target))
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(sections) { section in
                            SectionAccordion(section: section,
                                             isExpanded: uiState.isExpanded(section.id),
                                             onToggle: {})
                                .cardSurface()
                        }
                    }
                    .padding(Spacing.sm)
                }
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
                Task { await scoreboards.refresh() }
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
        if !scoreboards.selectedDayIsLoaded {
            ScrollView { SkeletonRows() }
        } else {
            VStack(spacing: Spacing.md) {
                Spacer()
                if let error = scoreboards.lastError {
                    Text(error)
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    Button("Retry") {
                        Task { await scoreboards.refresh() }
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
                    Text(emptyMessage(for: scoreboards.selectedDay))
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            // The stack is mostly empty space, which doesn't hit-test;
            // without this, the day swipe dies exactly where it's most
            // needed — on an empty day.
            .contentShape(Rectangle())
        }
    }

    private func emptyMessage(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "No games today" }
        if calendar.isDateInTomorrow(day) { return "No games tomorrow" }
        return "No games on \(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))"
    }

    /// What the narrowed-slate empty state says: live and the slate filter
    /// compose into one sentence.
    private var narrowedEmptyMessage: String {
        switch (uiState.liveOnly, uiState.scoreFilter) {
        case (true, let filter?): "No live \(filter.label) games right now"
        case (true, nil): "No live games right now"
        case (false, let filter?): "No \(filter.label) games this day"
        case (false, nil): ""
        }
    }
}
