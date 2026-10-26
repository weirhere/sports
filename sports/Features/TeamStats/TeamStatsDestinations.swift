import SwiftUI

extension View {
    /// The Team stats tab's two pushes — a stat's whole table and the
    /// StatSide rating's — for every stack that can reach a league page.
    /// One modifier, because there are five such stacks and a push nobody
    /// registered fails silently.
    func teamStatsDestinations() -> some View {
        navigationDestination(for: TeamStatRankingDestination.self) { destination in
            TeamStatRankingScreen(destination: destination)
        }
        .navigationDestination(for: StatSideRatingDestination.self) { destination in
            StatSideRatingScreen(destination: destination)
        }
    }
}
