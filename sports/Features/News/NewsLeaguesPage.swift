import SwiftUI

/// The News tab's Leagues page (Andy, 2026-10-19): the four league pages
/// that were four tabs, stacked on one, in the order the Leagues tab
/// lists them (`League.displayOrder`). Each league is a heading and its
/// five newest stories as full-width cards; a league with nothing says
/// so in its place rather than vanishing from the order.
struct NewsLeaguesPage: View {
    let stories: (League) -> [NewsStory]

    var body: some View {
        LazyVStack(spacing: Spacing.sm) {
            ForEach(League.displayOrder) { league in
                NewsLeagueSection(league: league, stories: stories(league))
            }
        }
    }
}
