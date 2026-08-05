import SwiftUI

struct RootView: View {
    enum Tab {
        case scores, rankings, teams
    }

    @State private var following = FollowingStore()
    @State private var uiState = UIStateStore()
    @State private var notifications = NotificationScheduler()
    @State private var router: Router
    @State private var selectedTab: Tab = .scores
    @State private var showOnboarding = false
    @State private var showReminderOffer = false
    @Environment(\.scenePhase) private var scenePhase

    init(router: Router = Router()) {
        _router = State(initialValue: router)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ScoresScreen()
                .tabItem { Label("Scores", systemImage: "football") }
                .tag(Tab.scores)
            RankingsScreen()
                .tabItem { Label("Rankings", systemImage: "list.number") }
                .tag(Tab.rankings)
            TeamsScreen()
                .tabItem { Label("Teams", systemImage: "shield.lefthalf.filled") }
                .tag(Tab.teams)
        }
        .tint(.primary)
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
            guard phase == .active else { return }
            Task {
                await notifications.refreshAuthorization()
                await notifications.resync(followedIds: following.teamIds)
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
    }
}

#Preview {
    RootView()
}
