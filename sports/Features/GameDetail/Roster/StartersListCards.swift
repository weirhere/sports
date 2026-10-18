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
            if isFootball {
                ForEach(GameRoster.Unit.allCases, id: \.self) { unit in
                    card(title: Self.title(for: unit), unit: unit)
                }
                card(title: "Also starting", unit: nil)
            } else {
                card(title: nil, unit: nil)
            }
        }
    }

    @ViewBuilder
    private func card(title: String?, unit: GameRoster.Unit?) -> some View {
        let away = starters(roster.away, unit: unit)
        let home = starters(roster.home, unit: unit)
        if !away.isEmpty || !home.isEmpty {
            RosterSidesCard(title: title, away: roster.away.team, home: roster.home.team,
                            awayItems: away, homeItems: home) { person, team in
                GameRosterCell(person: person, team: team, league: league)
            }
        }
    }

    /// A side's starters in `unit` — all of them where the league has no
    /// units — in jersey order.
    private func starters(_ side: GameRoster.Side, unit: GameRoster.Unit?) -> [GameRoster.Person] {
        let people = isFootball ? side.starters.filter { $0.unit == unit } : side.starters
        return GameRoster.Side.sortedByJersey(people)
    }

    static func title(for unit: GameRoster.Unit) -> String {
        switch unit {
        case .offense: "Offense"
        case .defense: "Defense"
        case .specialTeams: "Special teams"
        }
    }
}
