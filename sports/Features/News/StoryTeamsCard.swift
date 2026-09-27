import SwiftUI

/// "In this story" (N6): a row per team the story is tagged with, each the
/// Add teams sheet's `TeamFollowRow` — the body opens the team, the button
/// follows it. FotMob closes every article this way, so reading turns into
/// following.
///
/// Teams only. FotMob offers its competitions too, and StatSide's follows
/// are team-shaped by decision. A tag the directory can't place (a team
/// outside the four leagues, or a directory still loading) is left out
/// rather than drawn without a crest.
struct StoryTeamsCard: View {
    let teams: [Team]

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: "In this story")
            VStack(spacing: 0) {
                ForEach(Array(teams.enumerated()), id: \.element.followKey) { index, team in
                    TeamFollowRow(team: team, opensTeam: true)
                    if index < teams.count - 1 {
                        Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                    }
                }
            }
            .padding(.top, Spacing.xs)
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }
}
