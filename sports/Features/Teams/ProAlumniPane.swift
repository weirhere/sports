import SwiftUI

/// A college team page's Pros tab (2026-11-02): the school's players now in
/// the NFL, NBA and NHL, a card per league.
///
/// `RosterList`'s card stack — `CardHeader`, inset dividers, a lazy column
/// of rows — so the school's pros read in the same table language as its
/// own roster one tab over. Leagues in the app's order (NFL, NBA, NHL), an
/// empty league is no card, and within one the players run by pro team and
/// then name, so a school's five Eagles sit together.
struct ProAlumniPane: View {
    let alumni: [ProAlumnus]

    @Environment(TeamDirectoryStore.self) private var directory: TeamDirectoryStore?

    private static let leagues: [League] = [.nfl, .nba, .nhl, .wnba]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(Self.leagues, id: \.self) { league in
                let rows = rows(in: league)
                if !rows.isEmpty {
                    leagueCard(league, rows: rows)
                }
            }
        }
    }

    private func rows(in league: League) -> [(alumnus: ProAlumnus, team: Team?)] {
        alumni
            .filter { $0.league == league }
            .map { alumnus in
                (alumnus, alumnus.teamId.flatMap {
                    directory?.team(matching: TeamRef(id: $0, league: league))
                })
            }
            .sorted { lhs, rhs in
                let l = lhs.team?.displayName ?? lhs.team?.location ?? ""
                let r = rhs.team?.displayName ?? rhs.team?.location ?? ""
                return l != r ? l < r : lhs.alumnus.name < rhs.alumnus.name
            }
    }

    private func leagueCard(_ league: League,
                            rows: [(alumnus: ProAlumnus, team: Team?)]) -> some View {
        VStack(spacing: 0) {
            CardHeader(title: league.displayName, subtitle: String(rows.count))
            // Lazy for `RosterList`'s reason: Ohio State has ~60 NFL players,
            // and every row owns a headshot request.
            LazyVStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.alumnus.id) { index, row in
                    NavigationLink(value: row.alumnus.identity(team: row.team)) {
                        ProAlumnusRow(alumnus: row.alumnus, team: row.team)
                    }
                    .buttonStyle(.plain)
                    if index < rows.count - 1 {
                        Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                    }
                }
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }
}
