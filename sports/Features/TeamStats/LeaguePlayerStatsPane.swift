import SwiftUI

/// A league page's Player stats tab, left of Team stats (2026-10-26):
/// FotMob's player leaderboards in each sport's own numbers. Sections of
/// cards, each a stat's top three players, the header opening the whole
/// table. The page owns the fetch and the scope, as with Team stats.
struct LeaguePlayerStatsPane: View {
    let stats: LeaguePlayerStats?
    let failed: Bool
    let retry: () -> Void
    /// The page's teams, or nil for the whole league.
    var teamIds: Set<String>? = nil
    let scopeName: String
    let seasonLabel: String

    private var rankings: [PlayerStatRanking] {
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
                StatusMessage(text: "Couldn't load player stats.", retry: retry)
                    .cardSurface()
            } else {
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
        let first = PlayerStatDefinition.Section.allCases.first { !(grouped[$0] ?? []).isEmpty }
        return ForEach(PlayerStatDefinition.Section.allCases, id: \.self) { section in
            let cards = grouped[section] ?? []
            if !cards.isEmpty {
                sectionTitle(section.title, isFirst: section == first)
                ForEach(cards) { ranking in
                    PlayerStatLeaderCard(destination: PlayerStatRankingDestination(
                        ranking: ranking, scopeName: scopeName, seasonLabel: seasonLabel))
                }
            }
        }
    }

    /// Team stats' spacing, so the two tabs read alike: with the stack's
    /// 8pt, 32pt above a label, 16pt below it, and 16pt between the tab row
    /// and the first one (2026-10-26).
    private func sectionTitle(_ title: String, isFirst: Bool) -> some View {
        Text(title)
            .font(.sectionHeaderProminent)
            .foregroundStyle(.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, isFirst ? Spacing.lg : Spacing.xl)
            .padding(.bottom, Spacing.sm)
    }
}
