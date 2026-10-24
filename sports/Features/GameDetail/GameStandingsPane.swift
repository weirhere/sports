import SwiftUI

/// The game page's Standings tab: the tables the two sides sit in, both
/// rows tinted, under the team page's scope chip where the league has
/// scopes (2026-10-24).
///
/// One card per table, headed by its name, so a cross-conference game
/// reads as two tables with one highlighted row each and a divisional
/// game as one table with two. FotMob's match Table tab, in the app's
/// own table language.
struct GameStandingsPane: View {
    let game: Game
    let state: GameStandingsModel.State
    let scope: StandingsScope
    /// In-progress games for the rows' live dots. The screen passes the
    /// scoreboard's live slate for a current-season game and nothing for
    /// a past one, the conference page's rule.
    let liveGames: [Game]
    let onSelectScope: (StandingsScope) -> Void
    let onRetry: () -> Void

    private var league: League { game.home.team.league }
    private var scopes: [StandingsScope] { GameStandingsModel.scopes(in: league) }
    private var highlighted: Set<String> { [game.away.team.id, game.home.team.id] }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // The Plays tab's control row: the pane's one control, above
            // the cards it shapes. Absent in college football, which has
            // nothing to scope.
            if scopes.count > 1 {
                HStack(spacing: Spacing.sm) {
                    StandingsScopeChip(scopes: scopes, selection: scope,
                                       isNarrowed: scope.isNarrower(than: .conference),
                                       onSelect: onSelectScope)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.sm)
            }
            switch state {
            case .loaded(let tables) where !tables.isEmpty:
                ForEach(tables, id: \.name) { table in
                    card(table)
                }
            case .loaded:
                StatusMessage(text: "Standings TBA")
                    .cardSurface()
            case .failed:
                StatusMessage(text: "Couldn't load standings.", retry: onRetry)
                    .cardSurface()
            case .loading:
                // A lone spinner gets no card — a surface around it hugs
                // into a floating pill (Andy, 2026-08-31).
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            }
        }
        .padding(Spacing.sm)
    }

    private func card(_ table: ConferenceStandings) -> some View {
        VStack(spacing: 0) {
            CardHeader(title: title(for: table))
            StandingsList(
                entries: table.entries,
                highlightTeamIds: highlighted,
                // A division's top two are not the conference's, and only
                // college football's conferences play a top-two title game.
                showsTitleGameCut: table.parentId == nil
                    && Conference.titleGameIsTopTwo(
                        id: table.id, year: GameStandingsModel.seasonYear(for: game), in: league),
                liveGames: liveGames,
                highlightFill: .bgElevated
            )
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    /// The registry's name where it knows the table — "SEC", "NFC South" —
    /// and ESPN's own otherwise, so a realigned or unknown group still
    /// says what it is.
    private func title(for table: ConferenceStandings) -> String {
        let registered = Conference.name(for: table.conference)
        return registered == "Other" ? table.name : registered
    }
}
