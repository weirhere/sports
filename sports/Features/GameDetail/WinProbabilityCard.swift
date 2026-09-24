import SwiftUI

/// Who's likely to win, as ESPN models it (Coard Miller, 2026-09-24: "a
/// chart like ESPN does with their win probability… could you see a line of
/// 2.5 and suggest that it could potentially be a close game?").
///
/// The one ESPN extra that spends no color budget: before kickoff a split
/// bar in two grays, and once the game is under way a single-ink line of the
/// home side's chance through every play, over a hairline at 50%. No team
/// colors, no gradient. The card hides itself where the payload has neither
/// block, which is hockey, rather than giving hockey a meaning of its own.
struct WinProbabilityCard: View {
    let probability: WinProbability
    let away: Team
    let home: Team

    var body: some View {
        Group {
            switch probability {
            case .pregame(let homeShare, let awayShare):
                PregameSplit(away: away, home: home,
                             awayPercent: awayShare / (homeShare + awayShare) * 100)
            case .series(let points):
                ProbabilityLine(points: points, away: away, home: home)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    /// "Win probability, Liberty 56 percent, Coastal Carolina 44 percent."
    var spokenLabel: String {
        let homePercent = probability.homePercent.rounded()
        return "Win probability, \(away.location) \(Int(100 - homePercent)) percent, "
            + "\(home.location) \(Int(homePercent)) percent"
    }

    static func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }
}

/// Before kickoff: one bar, away's share on the left in ink, home's in gray.
private struct PregameSplit: View {
    let away: Team
    let home: Team
    let awayPercent: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                side(away, WinProbabilityCard.percent(awayPercent))
                Spacer()
                side(home, WinProbabilityCard.percent(100 - awayPercent))
            }
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    Capsule().fill(Color.textPrimary)
                        .frame(width: max(proxy.size.width * awayPercent / 100 - 1, 0))
                    Capsule().fill(Color.textSecondary.opacity(0.35))
                }
            }
            .frame(height: 6)
            Text("ESPN matchup predictor")
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
    }

    private func side(_ team: Team, _ percent: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(team.abbreviation ?? team.location)
                .font(.metaEmphasis)
                .foregroundStyle(.textPrimary)
            Text(percent)
                .font(.meta.monospacedDigit())
                .foregroundStyle(.textSecondary)
        }
    }
}

/// Under way: the home side's chance after every play. Home at the top
/// edge, away at the bottom, so the line climbs as home pulls ahead.
private struct ProbabilityLine: View {
    let points: [Double]
    let away: Team
    let home: Team

    private var leader: (team: Team, percent: Double) {
        let current = points.last ?? 0.5
        return current >= 0.5 ? (home, current * 100) : (away, (1 - current) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(leader.team.abbreviation ?? leader.team.location)
                    .font(.metaEmphasis)
                    .foregroundStyle(.textPrimary)
                Text(WinProbabilityCard.percent(leader.percent))
                    .font(.meta.monospacedDigit())
                    .foregroundStyle(.textSecondary)
            }
            HStack(spacing: Spacing.sm) {
                VStack {
                    LogoImage(url: home.logoURL).frame(width: 18, height: 18)
                    Spacer()
                    LogoImage(url: away.logoURL).frame(width: 18, height: 18)
                }
                chart
            }
            .frame(height: 96)
        }
    }

    private var chart: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                }
                .stroke(Color.divider, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = points.count > 1
                            ? size.width * CGFloat(index) / CGFloat(points.count - 1) : 0
                        let location = CGPoint(x: x, y: size.height * (1 - point))
                        if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
                    }
                }
                .stroke(Color.textPrimary, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
        }
    }
}
