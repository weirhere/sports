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
    @Environment(UIStateStore.self) private var uiState: UIStateStore?
    /// Where no store is in the environment (previews), the choice lives
    /// for the pane's lifetime.
    @State private var unsavedLayout: StartersLayout = .field

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
                    .padding(.horizontal, Spacing.sm)
            case .loaded(let roster):
                if roster.isEmpty {
                    StatusMessage(text: roster.phase == .upcoming ? "Lineups TBA" : "No lineup for this game.")
                        .cardSurface()
                        .padding(.horizontal, Spacing.sm)
                } else {
                    cards(roster)
                }
            }
        }
        // Bottom only: the Starters field bleeds edge to edge and meets the
        // tab row's hairline with no gap (Andy, 2026-10-18 — the 8pt of
        // page above it read as a seam), so each list card insets itself
        // and a pane that opens on anything else pads its own top.
        .padding(.bottom, Spacing.sm)
        .padding(.top, leadsWithField ? 0 : Spacing.sm)
        .onAppear { offenseTeamId = offenseTeamId ?? possessionTeamId }
    }

    private var layout: StartersLayout { uiState?.startersLayout ?? unsavedLayout }
    private var isFootball: Bool { league == .collegeFootball || league == .nfl }

    /// Whether the first thing on the pane is the painted field.
    private var leadsWithField: Bool {
        guard case .loaded(let roster) = state, layout == .field else { return false }
        return !roster.away.starters.isEmpty || !roster.home.starters.isEmpty
    }

    @ViewBuilder
    private func cards(_ roster: GameRoster) -> some View {
        let away = roster.away, home = roster.home
        if !away.starters.isEmpty || !home.starters.isEmpty {
            StartersSection(roster: roster, league: league,
                            layout: layout,
                            onLayoutChange: { layout in
                                if let uiState { uiState.startersLayout = layout } else { unsavedLayout = layout }
                            },
                            offenseTeamId: $offenseTeamId)
        }
        listCards(roster)
            .padding(.horizontal, Spacing.sm)
    }

    /// The two-column cards under the field, each in its own card.
    @ViewBuilder
    private func listCards(_ roster: GameRoster) -> some View {
        let away = roster.away, home = roster.home
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
        // Grouped by unit in football (Andy, 2026-10-18): the kicker and
        // the punter are never among the 22 ESPN flags as starters, so the
        // bench is where special teams live, and "Special teams" is the
        // caption that gives them a place. The inactives and the injured
        // stay one list each — those cards are about why, not where.
        let otherGroups = GameRoster.unitGroups(away: away.others, home: home.others, league: league)
        if !otherGroups.isEmpty {
            RosterSidesCard(title: othersTitle(roster), away: away.team, home: home.team,
                            groups: otherGroups.map { group in
                                .init(id: group.id,
                                      caption: isFootball ? (group.unit?.title ?? "Other") : nil,
                                      away: group.away, home: group.home)
                            }) { person, team in
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
