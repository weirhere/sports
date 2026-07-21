import SwiftUI

struct RootView: View {
    @State private var following = FollowingStore()
    @State private var uiState = UIStateStore()
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            ScoresScreen()
                .tabItem { Label("Scores", systemImage: "football") }
            RankingsScreen()
                .tabItem { Label("Rankings", systemImage: "list.number") }
            TeamsScreen()
                .tabItem { Label("Teams", systemImage: "shield.lefthalf.filled") }
        }
        .tint(.primary)
        .onAppear {
            // The pick-your-teams moment: offered once, and only to someone
            // who follows nobody (an upgrader with follows never sees it).
            if !uiState.onboardingSeen, !following.followsAnyone {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: { uiState.onboardingSeen = true }) {
            OnboardingScreen()
        }
        // Environment modifiers stay outside the sheet: sheet content only
        // inherits values applied above its attachment point.
        .environment(following)
        .environment(uiState)
    }
}

#Preview {
    RootView()
}
