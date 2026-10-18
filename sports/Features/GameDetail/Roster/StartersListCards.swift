import SwiftUI

/// The Starters section as the list the rest of the Roster tab is made
/// of (Andy, 2026-10-18): football's starters in an Offense, a Defense and
/// a Special teams card, the NBA's and NHL's in one, each a two-column
/// `RosterSidesCard` in jersey order — the team Roster tab's order, for
/// its reason. Every starter is placed; a football starter at a position
/// the unit table doesn't know gets an "Also starting" card rather than
/// a dropped row.
struct StartersListCards: View {
    let roster: GameRoster
    let league: League

    private var isFootball: Bool { league == .collegeFootball || league == .nfl }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(GameRoster.unitGroups(away: starters(roster.away), home: starters(roster.home),
                                          league: league)) { group in
                RosterSidesCard(title: isFootball ? (group.unit?.title ?? "Also starting") : nil,
                                away: roster.away.team, home: roster.home.team,
                                awayItems: group.away, homeItems: group.home) { person, team in
                    GameRosterCell(person: person, team: team, league: league)
                }
            }
        }
    }

    /// A side's starters in jersey order.
    private func starters(_ side: GameRoster.Side) -> [GameRoster.Person] {
        GameRoster.Side.sortedByJersey(side.starters)
    }
}
