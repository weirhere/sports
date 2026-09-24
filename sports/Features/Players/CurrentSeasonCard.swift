import SwiftUI

/// The player's season so far, in the three or four numbers their position
/// is about: games played, then yards, touchdowns and interceptions for a
/// quarterback, points, rebounds and assists for a guard, goals, assists and
/// points for a skater (E20's design, 2026-09-20; built 2026-09-24).
///
/// Which numbers is `PlayerStats.headlineNames(for:)`, keyed by ESPN's own
/// category name, so a relabelled column can't move them. The card is the
/// caller's to hide: no line for this season means no card, not zeroes.
struct CurrentSeasonCard: View {
    let seasonLabel: String
    let headlines: [PlayerStats.Headline]

    var body: some View {
        StatTilesCard(title: "This season", subtitle: seasonLabel,
                      tiles: headlines.map {
                          .init(label: $0.label, spokenLabel: $0.spokenLabel, value: $0.value)
                      })
    }
}

#Preview {
    CurrentSeasonCard(seasonLabel: "2026",
                      headlines: [.init(label: "GP", spokenLabel: "Games Played", value: "2"),
                                  .init(label: "YDS", spokenLabel: "Passing Yards", value: "566"),
                                  .init(label: "TD", spokenLabel: "Passing Touchdowns", value: "5"),
                                  .init(label: "INT", spokenLabel: "Interceptions", value: "1")])
        .padding()
        .background(Color.bgRecessed)
}
