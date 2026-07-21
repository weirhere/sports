import SwiftUI

struct RootView: View {
    @State private var following = FollowingStore()
    @State private var uiState = UIStateStore()

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
        .environment(following)
        .environment(uiState)
    }
}

#Preview {
    RootView()
}
