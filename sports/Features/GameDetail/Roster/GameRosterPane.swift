import SwiftUI

/// The game page's Roster tab (E29, 2026-10-18): who is in the game, in
/// FotMob's Lineup order — the starters drawn on the field, the coaches,
/// the bench, the inactives, and the injured at the bottom — with the away
/// side on the left of every card and the home side on the right.
///
/// The same five cards in every state; only their names move with it.
/// Before kickoff the bench card is the roster ("planning to play"), live
/// it is the bench, after the final it is everyone else who played.
struct GameRosterPane: View {
    enum LoadState {
        case loading
        case failed
        case loaded(GameRoster)
    }

    let league: League
    let state: LoadState
    /// Live football: whose offense the formation opens on.
    let possessionTeamId: String?
    let onRetry: () -> Void

    @Environment(CoachStaffStore.self) private var coachStaff: CoachStaffStore?

    /// Football's chip, owned here so it survives the card re-rendering.
    @State private var offenseTeamId: String?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            switch state {
            case .loading:
                // A lone spinner gets no card (Andy, 2026-08-31).
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            case .failed:
                StatusMessage(text: "Couldn't load the roster.", retry: onRetry)
                    .cardSurface()
            case .loaded(let roster):
                if roster.isEmpty {
                    StatusMessage(text: roster.phase == .upcoming ? "Lineups TBA" : "No lineup for this game.")
                        .cardSurface()
                } else {
                    cards(roster)
                }
            }
        }
        .padding(Spacing.sm)
        .onAppear { offenseTeamId = offenseTeamId ?? possessionTeamId }
    }

    @ViewBuilder
    private func cards(_ roster: GameRoster) -> some View {
        let away = roster.away, home = roster.home
        if !away.starters.isEmpty || !home.starters.isEmpty {
            FormationCard(roster: roster, league: league, offenseTeamId: $offenseTeamId)
        }
        let awayCoaches = GameCoachLine.lines(head: away.coach, staff: coachStaff?.staff(for: away.team) ?? [],
                                              league: league)
        let homeCoaches = GameCoachLine.lines(head: home.coach, staff: coachStaff?.staff(for: home.team) ?? [],
                                              league: league)
        if !awayCoaches.isEmpty || !homeCoaches.isEmpty {
            RosterSidesCard(title: "Coaches", away: away.team, home: home.team,
                            awayItems: awayCoaches, homeItems: homeCoaches) { line, team in
                GameCoachCell(coach: line, team: team, league: league)
            }
        }
        if !away.others.isEmpty || !home.others.isEmpty {
            RosterSidesCard(title: othersTitle(roster), away: away.team, home: home.team,
                            awayItems: away.others, homeItems: home.others) { person, team in
                GameRosterCell(person: person, team: team, league: league)
            }
        }
        if !away.inactive.isEmpty || !home.inactive.isEmpty {
            RosterSidesCard(title: inactiveTitle, away: away.team, home: home.team,
                            awayItems: away.inactive, homeItems: home.inactive) { person, team in
                GameRosterCell(person: person, team: team, league: league)
            }
        }
        if !away.injuries.isEmpty || !home.injuries.isEmpty {
            RosterSidesCard(title: "Injuries", away: away.team, home: home.team,
                            awayItems: away.injuries, homeItems: home.injuries) { injury, team in
                GameInjuryCell(injury: injury, team: team, league: league)
            }
        }
    }

    /// What the non-starters are, in this state of the game. A pre-game
    /// side with no projected starters at all is simply its roster.
    private func othersTitle(_ roster: GameRoster) -> String {
        switch roster.phase {
        case .upcoming: "Roster"
        case .live: "Bench"
        case .played: "Also played"
        }
    }

    /// Each league's own word for the players who dressed in name only.
    private var inactiveTitle: String {
        switch league {
        case .collegeFootball, .nfl: "Inactive"
        case .nba: "Did not play"
        case .nhl: "Scratched"
        }
    }
}
