import SwiftUI

/// The Roster tab's lineup section — not a card: the field runs edge to
/// edge, because eleven across a phone needs every point it can get and
/// the card's inset and the field's own margin were costing it 40 (Andy,
/// 2026-10-18). The title and the strips keep the cards' text margin and
/// sit on the surface's paint a shade deeper than the field's, with no
/// divider under the title: the section is one painted place from its
/// name down to its last strip, not a header over a picture, and the
/// shade change is where the field begins (Andy, same day — on a single
/// green the heading and the first row ran together).
///
/// In football a strip at each end names its team and holds the chips
/// that decide whose offense is drawn — one team's eleven across the line
/// from the other team's eleven, which is the picture a snap makes and
/// the only honest one for a sport whose "lineup" changes every change of
/// possession. The top team's strip sits under the title and the bottom
/// team's under the field, each reading its own unit, so the two always
/// disagree (the Figma sheet "↳ Roster variants", 2026-10-27; until then
/// one row of "HOU offense" chips under the title, and a caption at each
/// end of the field). The court and the rink, whose lineups don't change
/// with the ball, name their teams in plain bars, one at each end.
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
                // 16pt above and below a row of 32pt chips: a 64pt title
                // row (the Figma sheet, 2026-10-27). The header pads no
                // vertical of its own; this is its whole margin.
                StartersHeader(roster: roster, league: league, layout: layout,
                               onLayoutChange: onLayoutChange, ink: ink)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.lg)
                if isFootball {
                    strip(for: away.team, opponent: home.team, isOffense: awayHasBall)
                } else {
                    SurfaceCaptionBar(team: away.team, league: league)
                }
            }
            // A shade deeper than the field, so the heading reads as the
            // section's and the field begins where the shade changes
            // (Andy, 2026-10-18 — on one green they ran together).
            .background(SurfaceColors.heading(for: league))
            FormationField(league: league,
                           top: formation(for: away, isOffense: awayHasBall),
                           bottom: formation(for: home, isOffense: !awayHasBall),
                           topTeam: away.team, bottomTeam: home.team)
                .background(SurfaceColors.base(for: league))
            Group {
                if isFootball {
                    strip(for: home.team, opponent: away.team, isOffense: !awayHasBall)
                } else {
                    SurfaceCaptionBar(team: home.team, league: league)
                }
            }
            .background(SurfaceColors.heading(for: league))
            unplacedRows
                .padding(.horizontal, Spacing.sm)
        }
    }

    /// A team's strip; picking its Offense puts its offense on the field,
    /// picking its Defense puts the other team's there.
    private func strip(for team: Team, opponent: Team, isOffense: Bool) -> some View {
        UnitStrip(team: team, opponent: opponent, league: league, isOffense: isOffense, ink: ink) { offense in
            offenseTeamId = offense ? team.id : opponent.id
        }
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
}
