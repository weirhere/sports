import SwiftUI

/// The Roster tab's lineup section — not a card: the field runs edge to
/// edge, because eleven across a phone needs every point it can get and
/// the card's inset and the field's own margin were costing it 40 (Andy,
/// 2026-10-18). The title and the chips keep the cards' text margin and
/// sit on the surface's paint a shade deeper than the field's, with no
/// divider under the title: the section is one painted place from its
/// name down to the last row, not a header over a picture, and the shade
/// change is where the field begins (Andy, same day — on a single green
/// the heading and the first row ran together).
/// The two starting units on one field, and
/// in football the chip row that decides whose offense is drawn — one
/// team's eleven across the line from the other team's eleven, which is
/// the picture a snap makes and the only honest one for a sport whose
/// "lineup" changes every change of possession. The chips say "HOU
/// offense": a "HOU has the ball" wording was tried and reverted the same
/// day — the unit's name felt better (Andy, 2026-10-18).
struct FormationCard: View {
    let roster: GameRoster
    let league: League
    /// Football: the team whose offense is on the field. Owned by the pane
    /// so a chip tap survives this card re-rendering under a poll.
    @Binding var offenseTeamId: String?
    /// The Field / List chips on the title row (Andy, 2026-10-18).
    let layout: StartersLayout
    let onLayoutChange: (StartersLayout) -> Void

    private var isFootball: Bool { league == .collegeFootball || league == .nfl }
    private var away: GameRoster.Side { roster.away }
    private var home: GameRoster.Side { roster.home }

    private var awayHasBall: Bool { offenseTeamId != home.team.id }
    private var ink: SurfaceColors.Ink { SurfaceColors.ink(for: league) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                StartersHeader(roster: roster, layout: layout, onLayoutChange: onLayoutChange, ink: ink)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xs)
                if isFootball {
                    HStack(spacing: Spacing.sm) {
                        SlateToggleChip(title: "\(shortName(away.team)) offense", isOn: awayHasBall,
                                        hint: "Draws \(away.team.location)'s offense against \(home.team.location)'s defense",
                                        ink: ink) {
                            offenseTeamId = away.team.id
                        }
                        SlateToggleChip(title: "\(shortName(home.team)) offense", isOn: !awayHasBall,
                                        hint: "Draws \(home.team.location)'s offense against \(away.team.location)'s defense",
                                        ink: ink) {
                            offenseTeamId = home.team.id
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.sm + Spacing.md)
                }
            }
            .padding(.bottom, Spacing.sm)
            // A shade deeper than the field, so the heading reads as the
            // section's and the field begins where the shade changes
            // (Andy, 2026-10-18 — on one green they ran together).
            .background(SurfaceColors.heading(for: league))
            FormationField(league: league,
                           top: formation(for: away, isOffense: awayHasBall),
                           bottom: formation(for: home, isOffense: !awayHasBall),
                           topTeam: away.team, bottomTeam: home.team,
                           topLabel: unitLabel(for: away.team, isOffense: awayHasBall),
                           bottomLabel: unitLabel(for: home.team, isOffense: !awayHasBall))
                .background(SurfaceColors.base(for: league))
            unplacedRows
                .padding(.horizontal, Spacing.sm)
        }
        .padding(.bottom, Spacing.xs)
    }

    /// Starters the layout couldn't place — a position the table doesn't
    /// know — named under the field rather than dropped.
    @ViewBuilder
    private var unplacedRows: some View {
        let awayUnplaced = formation(for: away, isOffense: awayHasBall)?.unplaced ?? []
        let homeUnplaced = formation(for: home, isOffense: !awayHasBall)?.unplaced ?? []
        if !awayUnplaced.isEmpty || !homeUnplaced.isEmpty {
            HStack(alignment: .top, spacing: 0) {
                unplacedColumn(awayUnplaced, team: away.team)
                unplacedColumn(homeUnplaced, team: home.team)
            }
            .padding(.bottom, Spacing.xs)
        }
    }

    private func unplacedColumn(_ people: [GameRoster.Person], team: Team) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !people.isEmpty {
                Text("Also starting")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
                ForEach(people) { person in
                    GameRosterCell(person: person, team: team, league: league)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func formation(for side: GameRoster.Side, isOffense: Bool) -> Formation? {
        guard !side.starters.isEmpty else { return nil }
        return Formation.make(starters: side.starters, league: league,
                              unit: isFootball ? (isOffense ? .offense : .defense) : nil)
    }

    private func unitLabel(for team: Team, isOffense: Bool) -> String? {
        guard isFootball else { return nil }
        return "\(shortName(team)) \(isOffense ? "offense" : "defense")"
    }

    private func shortName(_ team: Team) -> String { team.abbreviation ?? team.location }

}
