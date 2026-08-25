import SwiftUI

struct RootView: View {
    enum Tab {
        case scores, rankings, teams, search
    }

    @State private var following = FollowingStore()
    @State private var uiState = UIStateStore()
    @State private var notifications = NotificationScheduler()
    // Scoreboard and team directory live here, not in their tabs, so the
    // search cover (and any tab) sees the same loaded data, and polling
    // follows the scene's lifecycle instead of one tab's.
    @State private var scoreboard = ScoreboardStore(client: DataProvider.makeClient())
    @State private var directory = TeamDirectoryStore()
    @State private var router: Router
    @State private var selectedTab: Tab = .scores
    /// Where Cancel on the search tab returns to.
    @State private var lastContentTab: Tab = .scores
    @State private var showOnboarding = false
    @State private var showReminderOffer = false
    @Environment(\.scenePhase) private var scenePhase

    init(router: Router = Router()) {
        _router = State(initialValue: router)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SwiftUI.Tab("Scores", systemImage: "football", value: Tab.scores) {
                ScoresScreen()
            }
            SwiftUI.Tab("Rankings", systemImage: "list.number", value: Tab.rankings) {
                RankingsScreen()
            }
            SwiftUI.Tab("Teams", systemImage: "shield.lefthalf.filled", value: Tab.teams) {
                TeamsScreen()
            }
            // The search role renders FotMob-style on iOS 26 — a separate
            // circular magnifier beside the floating tab bar. iOS 18 shows
            // it as a plain fourth tab.
            SwiftUI.Tab(value: Tab.search, role: .search) {
                SearchScreen(onCancel: { selectedTab = lastContentTab })
            }
        }
        .tint(.primary)
        .task { await scoreboard.loadInitial() }
        .task { await directory.load() }
        .onAppear {
            // The pick-your-teams moment: offered once, and only to someone
            // who follows nobody (an upgrader with follows never sees it).
            if !uiState.onboardingSeen, !following.followsAnyone {
                showOnboarding = true
            }
        }
        .onOpenURL { url in
            guard let link = DeepLink(url: url) else { return }
            router.open(link)
            switch link {
            case .game: selectedTab = .scores
            case .team, .teams: selectedTab = .teams
            }
        }
        // Notification taps set the pending id directly (no URL); the tab
        // switch lives here so both entry paths land the same way.
        .onChange(of: router.pendingGameId) { _, id in
            if id != nil { selectedTab = .scores }
        }
        .onChange(of: router.pendingTeamId) { _, id in
            if id != nil { selectedTab = .teams }
        }
        .onChange(of: router.pendingConferenceId) { _, id in
            if id != nil { selectedTab = .teams }
        }
        .onChange(of: router.pendingTeamsBrowse) { _, pending in
            guard pending else { return }
            selectedTab = .teams
            router.pendingTeamsBrowse = false
        }
        .onChange(of: selectedTab) { _, tab in
            if tab != .search { lastContentTab = tab }
        }
        .onChange(of: following.teamIds) { oldIds, newIds in
            Task { await notifications.resync(followedIds: newIds) }
            // The contextual permission moment: right after the first-ever
            // follow, once, and never at launch.
            if oldIds.isEmpty, !newIds.isEmpty, !uiState.notificationsPrompted,
               !notifications.remindersOn {
                uiState.notificationsPrompted = true
                showReminderOffer = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                scoreboard.startPollingIfNeeded()
                Task {
                    await notifications.refreshAuthorization()
                    await notifications.resync(followedIds: following.teamIds)
                }
            } else {
                scoreboard.stopPolling()
            }
        }
        .alert("Get kickoff reminders?", isPresented: $showReminderOffer) {
            Button("Enable") {
                Task { await notifications.requestAndEnable(followedIds: following.teamIds) }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("A heads-up 30 minutes before each of your teams' games.")
        }
        .sheet(isPresented: $showOnboarding, onDismiss: { uiState.onboardingSeen = true }) {
            OnboardingScreen()
        }
        // Environment modifiers stay outside the sheet: sheet content only
        // inherits values applied above its attachment point.
        .environment(following)
        .environment(uiState)
        .environment(router)
        .environment(notifications)
        .environment(scoreboard)
        .environment(directory)
    }
}

#Preview {
    RootView()
}
