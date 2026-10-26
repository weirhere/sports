import SwiftUI

/// A league page's Team stats tab: FotMob's league Team stats, in each
/// sport's own numbers (2026-10-25). Sections of cards, each card a stat's
/// top three with its header opening the whole table.
///
/// The pane draws what the page hands it. The page owns the fetch (one
/// `byteam` request per season) and decides the scope — every team on a
/// league page, the members on a conference page, ranked among themselves.
struct LeagueTeamStatsPane: View {
    let stats: LeagueTeamStats?
    let failed: Bool
    let retry: () -> Void
    /// The page's teams, or nil for the whole league.
    var teamIds: Set<String>? = nil
    /// "NFL", "SEC" — whose tables these are, for the full lists.
    let scopeName: String
    let seasonLabel: String
    /// College football's StatSide rating, leading Top stats. Nil where the
    /// page doesn't carry one; empty while its standings are still coming.
    var rating: [StatSideRating.Row]? = nil

    private var rankings: [TeamStatRanking] {
        stats?.rankings(among: teamIds) ?? []
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if let stats, stats.hasPlayed, !rankings.isEmpty {
                sections
            } else if stats != nil {
                StatusMessage(text: "No games yet this season.")
                    .cardSurface()
            } else if failed {
                StatusMessage(text: "Couldn't load team stats.", retry: retry)
                    .cardSurface()
            } else {
                // A lone spinner gets no card (ConferencePage's rule).
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    private var sections: some View {
        let grouped = Dictionary(grouping: rankings, by: \.definition.section)
        return ForEach(TeamStatDefinition.Section.allCases, id: \.self) { section in
            let cards = grouped[section] ?? []
            if !cards.isEmpty {
                sectionTitle(section.title)
                if section == .top, let rating, !rating.isEmpty {
                    StatSideRatingCard(destination: StatSideRatingDestination(rows: rating,
                                                                              seasonLabel: seasonLabel))
                }
                ForEach(cards) { ranking in
                    TeamStatLeaderCard(destination: TeamStatRankingDestination(
                        ranking: ranking, scopeName: scopeName, seasonLabel: seasonLabel))
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.sectionHeaderProminent)
            .foregroundStyle(.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.sm)
    }
}
