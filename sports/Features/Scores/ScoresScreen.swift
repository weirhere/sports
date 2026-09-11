import SwiftUI
import os

/// The product: one screen answering "what's the state of the day" in one
/// thumb, one scroll. Day strip → Following → the tables you follow → the
/// day's slate, conference by conference for college football and whole
/// for the NFL.
///
/// The league used to be a segmented control and the day a week (Andy,
/// 2026-09-05). Both changed for the same reason: a selector shows one
/// league at a time and has to grow a segment per sport, while a week strip
/// can only ever be honest about one league's calendar.
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
    @State private var showsCalendar = false
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
    // The day the panes keep rendering while a committed swipe slides
    // home. A swipe commits its day the instant the thumb lifts — the
    // strip, the header and the Today button move then, not when the
    // animation lands (Andy, 2026-09-07) — so the outgoing slate needs a
    // day of its own for the ~0.3s it spends leaving.
    @State private var settlingFrom: Date?
    /// The pending intent whose day is already being fetched — one attempt
    /// per intent, so a game missing from the day it claims can't spin.
    @State private var pendingDayFetch: String?

    private enum DragAxis { case horizontal, vertical }

    /// Height of the floating Today button plus its breathing room.
    private static let jumpClearance: CGFloat = 44

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScoresHeader(liveOnly: uiState.liveOnly,
                             onToggleLive: { toggleLive() },
                             onOpenCalendar: { showsCalendar = true })
                DayStrip(days: scoreboards.days(),
                         selectedId: DayFormat.id(for: scoreboards.selectedDay)) { day in
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
                        .id(DayFormat.id(for: shownDay))
                        .transition(.push(from: daySlideEdge))
                        .offset(x: dragOffset)
                    // The adjacent day rides in with the finger. Its games
                    // are already in hand — every fetch is a five-day
                    // window, so both neighbours land in the same request
                    // the shown day did.
                    if dragOffset != 0,
                       let target = scoreboards.adjacentDay(offset: dragOffset < 0 ? 1 : -1,
                                                            from: shownDay) {
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
                .animation(daySlideAnimation, value: shownDay)
                // Horizontal counterpart to the day strip: swipe left for
                // tomorrow, right for yesterday. Simultaneous so vertical
                // scrolling and the pinch gesture are unaffected; attached
                // here (not inside `content`) so the empty day and error
                // states are swipeable too — the states where leaving the
                // day matters most.
                .simultaneousGesture(daySwipeGesture)
            }
            .background(Color.bgPrimary)
            .overlay(alignment: .bottom) {
                if scoreboards.showsTodayJump { todayJump }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85),
                       value: scoreboards.showsTodayJump)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Game.self) { game in
                GameDetailScreen(game: game)
            }
            // Identity follows the conference, for the reason the team
            // destination below does: a replaced value at the same path
            // position otherwise reuses the page and its caches.
            .navigationDestination(for: ConferenceDestination.self) { destination in
                ConferencePage(destination: destination)
                    .id(destination)
            }
            // Identity follows the team (2026-09-10). Search and the
            // widget route by *replacing* the value at this path position
            // rather than pushing a second page, and a destination whose
            // identity doesn't change is reused with all of its `@State`
            // intact — which is how the Lakers page came to show Ole Miss's
            // schedule, standings and roster under a Lakers crest.
            .navigationDestination(for: Team.self) { team in
                TeamPage(team: team)
                    .id(team.followKey)
            }
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
        // only while an FCS conference is followed (E8 scope (b) — the
        // filter half of the rule left with the slate filter itself).
        // `select(divisions:)` refetches and no-ops when nothing changed —
        // so this fires freely.
        .task(id: neededDivisions) { await scoreboards.select(divisions: neededDivisions) }
        .sheet(isPresented: $showsCalendar) {
            DayCalendarSheet(days: scoreboards.days(),
                             selected: scoreboards.selectedDay) { day in
                select(day: day)
            }
        }
        .onChange(of: router.pendingGame) { _, pending in
            guard pending != nil else { return }
            // A fresh intent gets its own day fetch, even where it repeats
            // an id whose day has since been evicted from the cache.
            pendingDayFetch = nil
            resolvePendingGame()
        }
        // The cold-launch race: a widget tap sets its intent while the
        // first window is still in flight, and resolving against an empty
        // store fails silently — which is every widget tap on a freshly
        // launched app. Each load's end is another chance at it.
        .onChange(of: scoreboards.isLoading) { _, loading in
            if !loading { resolvePendingGame() }
        }
        .onChange(of: scoreboards.selectedDay) { _, _ in
            // A settling swipe owns the offset until its slide lands. Every
            // other day change — a chip, the calendar, the Today jump, a
            // snap forward — starts from rest anyway.
            if settlingFrom == nil { dragOffset = 0 }
            resolvePendingGame()
        }
    }

    private var neededDivisions: Set<Conference.Division> {
        ScoreboardStore.divisions(filter: nil,
                                  followedConferenceIds: following.conferenceIds)
    }

    /// The day the content panes are drawn for: the selected one, except
    /// during a settling swipe, where the selected day is already the one
    /// arriving from the edge.
    private var shownDay: Date { settlingFrom ?? scoreboards.selectedDay }

    private var sections: [GameSection] {
        scoreboards.sections(day: shownDay,
                             followingIds: following.teamKeys,
                             followedTables: following.orderedTables,
                             liveOnly: uiState.liveOnly)
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

    /// The way back to today: centred over the slate, just above the tab
    /// bar (Andy, 2026-09-06). It used to be a chip pinned to the day
    /// strip's trailing edge, which cost the strip its last ~70pt on every
    /// day but today — a floating button costs it nothing and sits where
    /// the thumb already is.
    ///
    /// Inverted, alone in the app's chrome: dark on light, light on dark —
    /// `textPrimary` ground under `bgPrimary` ink, the same pairing the
    /// selected day chip wears. It is the one control on the page that
    /// *changes* the day rather than describing it, and it only exists
    /// while it has somewhere to go, so it can afford to be the loudest
    /// thing on screen.
    ///
    /// "Somewhere to go" means off the strip, not just off today (Andy,
    /// 2026-09-07): a day or two out the Today chip is still up there, and
    /// two Todays a thumb apart is one too many.
    private var todayJump: some View {
        Button {
            select(day: .now)
        } label: {
            Text("Today")
                .font(.chip)
                .fixedSize()
                .foregroundStyle(Color.bgPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .glassCapsuleInteractive(tint: Color.textPrimary,
                                         fallback: Color.textPrimary)
        }
        .buttonStyle(.plain)
        // Floating over scrolling content, so it carries its own separation
        // on the 18.0 floor where there is no glass to do it.
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        .padding(.bottom, Spacing.md)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .accessibilityLabel("Jump to today")
        .accessibilityIdentifier("scores-today-jump")
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
                // A new drag lands the settling one on the spot: its day is
                // already selected, so there is nothing left to wait for.
                if settlingFrom != nil {
                    settlingFrom = nil
                    dragOffset = 0
                }
                let dx = value.translation.width
                let dy = value.translation.height
                if dragAxis == nil, abs(dx) > 10 || abs(dy) > 10 {
                    dragAxis = abs(dx) > abs(dy) * 1.5 ? .horizontal : .vertical
                }
                guard dragAxis == .horizontal else { return }
                let hasTarget = scoreboards.adjacentDay(offset: dx < 0 ? 1 : -1,
                                                        from: shownDay) != nil
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
                      let target = scoreboards.adjacentDay(offset: dx < 0 ? 1 : -1,
                                                           from: shownDay) else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        dragOffset = 0
                    }
                    return
                }
                // The day changes here, on the frame the thumb lifts — the
                // strip must never lag the gesture that moved it. The slate
                // finishes its slide afterwards, drawn for `settlingFrom`.
                let leaving = shownDay
                settlingFrom = leaving
                daySlideAnimation = nil
                scoreboards.show(day: target)
                Task { await scoreboards.loadSelectedDay() }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.95),
                              completionCriteria: .logicallyComplete) {
                    dragOffset = dx < 0 ? -paneWidth : paneWidth
                } completion: {
                    // The push transition is the chip taps' mechanism; the
                    // drag already animated, so the handoff is instant —
                    // the preview pane is already sitting where the content
                    // lands. Skipped when a newer swipe took over.
                    guard settlingFrom == leaving else { return }
                    settlingFrom = nil
                    dragOffset = 0
                }
            }
    }

    /// Lands a widget/notification tap on its game.
    ///
    /// The first search space is memory — every day in hand across every
    /// league. That is five days, and the widget lists games from
    /// yesterday to a fortnight out, so most of what a widget row can show
    /// isn't there: an intent that knows its day sends the strip to that
    /// day and looks again once the slate lands (Andy, 2026-09-07).
    ///
    /// One day fetch per intent, so an id that genuinely isn't in that
    /// day's slate can't loop. An id that never resolves still degrades to
    /// landing on Scores, and expires when the next intent replaces it.
    private func resolvePendingGame() {
        guard let pending = router.pendingGame else { return }
        if let game = scoreboards.game(id: pending.id) {
            router.pendingGame = nil
            pendingDayFetch = nil
            path = NavigationPath([game])
            return
        }
        guard let day = pending.day, pendingDayFetch != pending.id else { return }
        pendingDayFetch = pending.id
        // A deep link isn't a directional move through the strip, so it
        // arrives the way the first load does: no slide.
        daySlideAnimation = nil
        Task {
            await scoreboards.open(day: day)
            resolvePendingGame()
        }
    }

    /// The slate, however it lands: games, an empty day, an error, or the
    /// first-load skeleton. `bgRecessed` is painted once out here so every
    /// one of those stands on the same ground — an empty day used to fall
    /// through to the window's `bgPrimary` and read as a different screen.
    private var content: some View {
        slate
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgRecessed)
    }

    @ViewBuilder
    private var slate: some View {
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
                // The jump floats over this scroll view, so the last card
                // needs room to clear it rather than sitting underneath.
                .padding(.bottom, scoreboards.showsTodayJump ? Self.jumpClearance : 0)
            }
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
                                            followedTables: following.orderedTables,
                                            liveOnly: uiState.liveOnly)
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
        if !scoreboards.isLoaded(shownDay) {
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
                } else if uiState.liveOnly {
                    // The narrowed-slate empty state: name what's hiding
                    // the games, and offer the whole slate back.
                    Text("No live games right now")
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    Button("Show all games") {
                        withAnimation { uiState.liveOnly = false }
                    }
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
                } else {
                    Text(emptyMessage(for: shownDay))
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
}
