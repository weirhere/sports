import SwiftUI

extension View {
    /// The stats tabs' pushes — a team stat's whole table, a player stat's,
    /// and the StatSide rating's — for every stack that can reach a league
    /// page.
    /// One modifier, because there are five such stacks and a push nobody
    /// registered fails silently.
    func leagueStatsDestinations() -> some View {
        navigationDestination(for: TeamStatRankingDestination.self) { destination in
            TeamStatRankingScreen(destination: destination)
        }
        .navigationDestination(for: PlayerStatRankingDestination.self) { destination in
            PlayerStatRankingScreen(destination: destination)
        }
        .navigationDestination(for: StatSideRatingDestination.self) { destination in
            StatSideRatingScreen(destination: destination)
        }
    }
}
