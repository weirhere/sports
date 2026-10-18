import SwiftUI

/// The Roster tab's Starters section in whichever layout the reader chose
/// (Andy, 2026-10-18): the painted field, full bleed with its title row on
/// the paint, or the list cards, inset like every other card on the tab
/// with the title row on the page above them. The choice is one chip tap
/// on the section and persists (`UIStateStore.startersLayout`).
struct StartersSection: View {
    let roster: GameRoster
    let league: League
    let layout: StartersLayout
    let onLayoutChange: (StartersLayout) -> Void
    /// Football: whose offense the field draws. Owned by the pane so a
    /// chip tap survives this section re-rendering under a poll.
    @Binding var offenseTeamId: String?

    var body: some View {
        switch layout {
        case .field:
            FormationCard(roster: roster, league: league, offenseTeamId: $offenseTeamId,
                          layout: layout, onLayoutChange: onLayoutChange)
        case .list:
            VStack(spacing: Spacing.sm) {
                StartersHeader(roster: roster, layout: layout, onLayoutChange: onLayoutChange)
                StartersListCards(roster: roster, league: league)
            }
            .padding(.horizontal, Spacing.sm)
        }
    }
}
