import SwiftUI

/// Who's likely to win, as ESPN models it: one row, FotMob's "Who will win?"
/// card without the vote (Andy, 2026-09-24). Each side's crest with its
/// percentage, centred in half of the row: away on the left, home on the
/// right, as in the header.
/// The favorite's number is the one in ink and weight. There's no draw
/// column, and no chart.
///
/// Which number it shows depends on the moment, and the header's trailing
/// caption says which:
/// - **Before kickoff:** ESPN's matchup predictor.
/// - **Live:** the latest per-play value.
/// - **Final:** the value at kickoff. The current value would just be
///   100–0, while the kickoff value is what an upset was measured against.
///
/// It spends no color: emphasis is weight and ink only. The card hides
/// itself where the payload has neither block (hockey).
struct WinProbabilityCard: View {
    let probability: WinProbability
    let isFinal: Bool
    let away: Team
    let home: Team

    @ScaledMetric(relativeTo: .body) private var crestSize: CGFloat = 24

    /// The home side's percentage for this moment, and the header's
    /// caption naming where it came from.
    static func reading(_ probability: WinProbability,
                        isFinal: Bool) -> (homePercent: Double, caption: String) {
        switch probability {
        case .pregame:
            return (probability.homePercent, "ESPN predictor")
        case .series(let points):
            let point = (isFinal ? points.first : points.last) ?? 0.5
            return (point * 100, isFinal ? "At kickoff" : "Live")
        }
    }

    private var homePercent: Double { Self.reading(probability, isFinal: isFinal).homePercent }

    var body: some View {
        let home = Int(homePercent.rounded())
        let away = 100 - home
        // Two equal halves, each group centred in its own (FotMob's layout),
        // so the numbers sit apart from the card's edges.
        HStack(spacing: 0) {
            side(self.away, percent: away, leads: away > home)
                .frame(maxWidth: .infinity)
            side(self.home, percent: home, leads: home > away)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    private func side(_ team: Team, percent: Int, leads: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            LogoImage(url: team.logoURL)
                .frame(width: crestSize, height: crestSize)
            Text("\(percent)%")
                .font(leads ? .score : .scoreMuted)
                .foregroundStyle(leads ? Color.textPrimary : Color.textSecondary)
        }
    }

    /// "Win probability at kickoff, Liberty 56 percent, Coastal Carolina 44
    /// percent." The caption rides in the sentence, lowercased.
    var spokenLabel: String {
        let reading = Self.reading(probability, isFinal: isFinal)
        let home = Int(reading.homePercent.rounded())
        let moment = switch reading.caption {
        case "At kickoff": " at kickoff"
        case "Live": " now"
        default: ""
        }
        return "Win probability\(moment), \(away.location) \(100 - home) percent, "
            + "\(self.home.location) \(home) percent"
    }
}
