import SwiftUI

/// One game on a team page, from that team's perspective:
/// date · vs/@ opponent · result or kick time.
struct ScheduleRow: View {
    let game: Game
    let teamId: String

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(game.date?.formatted(.dateTime.month(.abbreviated).day()) ?? "TBD")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text(isHome ? "vs" : "@")
                .font(.meta)
                .foregroundStyle(.textSecondary)
            LogoImage(url: opponent.team.logoURL)
                .frame(width: logoSize, height: logoSize)
            Text(opponent.team.location)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            Spacer()
            trailing
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// One spoken sentence from this team's perspective: "September 27,
    /// versus Tennessee, won 24 to 17". Internal for unit tests.
    var accessibilitySummary: String {
        var parts: [String] = []
        if let date = game.date {
            parts.append(date.formatted(.dateTime.month(.wide).day()))
        }
        parts.append("\(isHome ? "versus" : "at") \(opponent.team.location)")
        switch game.status {
        case .final:
            let outcome = mine.winner == true ? "won" : (opponent.winner == true ? "lost" : "final")
            parts.append("\(outcome) \(spokenScore)")
        case .live:
            parts.append("live, \(spokenScore)")
        case .pre:
            if let date = game.date {
                parts.append("kickoff \(date.formatted(.dateTime.hour().minute()))")
            }
        case .other(let detail):
            if let detail { parts.append(detail) }
        }
        return parts.joined(separator: ", ")
    }

    private var spokenScore: String {
        "\(mine.score.map(String.init) ?? "no score") to \(opponent.score.map(String.init) ?? "no score")"
    }

    private var isHome: Bool { game.home.team.id == teamId }
    private var mine: Competitor { isHome ? game.home : game.away }
    private var opponent: Competitor { isHome ? game.away : game.home }

    @ViewBuilder
    private var trailing: some View {
        switch game.status {
        case .final:
            HStack(spacing: Spacing.xs) {
                Text(mine.winner == true ? "W" : (opponent.winner == true ? "L" : "–"))
                    .font(.metaEmphasis)
                    .foregroundStyle(.textPrimary)
                Text("\(mine.score.map(String.init) ?? "–")-\(opponent.score.map(String.init) ?? "–")")
                    .font(.score)
                    .foregroundStyle(.textPrimary)
            }
        case .live:
            HStack(spacing: Spacing.xs) {
                LiveDot()
                Text("\(mine.score.map(String.init) ?? "–")-\(opponent.score.map(String.init) ?? "–")")
                    .font(.scoreLive)
                    .foregroundStyle(.textPrimary)
            }
        case .pre:
            Text(game.date?.formatted(.dateTime.hour().minute()) ?? "TBD")
                .font(.meta)
                .foregroundStyle(.textSecondary)
        case .other(let detail):
            Text(detail ?? "—")
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
    }
}
