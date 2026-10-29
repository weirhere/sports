import SwiftUI

extension View {
    /// The stats tabs' pushes — a team stat's whole table and a player
    /// stat's — for every stack that can reach a league page.
    /// One modifier, because there are five such stacks and a push nobody
    /// registered fails silently.
    func leagueStatsDestinations() -> some View {
        navigationDestination(for: TeamStatRankingDestination.self) { destination in
            TeamStatRankingScreen(destination: destination)
        }
        .navigationDestination(for: PlayerStatRankingDestination.self) { destination in
            PlayerStatRankingScreen(destination: destination)
        }
    }
}
