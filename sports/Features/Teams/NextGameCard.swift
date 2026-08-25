import SwiftUI

/// The team page's lead card: the current season's next unplayed game as
/// a matchup — both sides with rank and trailing record, kick day/time
/// and network across a hairline column. Tapping pushes the game's detail.
struct NextGameCard: View {
    let game: Game
    let teamId: String

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: "Next game")
            NavigationLink(value: game) {
                HStack(spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        sideLine(game.away)
                        sideLine(game.home)
                    }
                    Rectangle()
                        .fill(Color.divider)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                    statusColumn
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.lg)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
            }
            .buttonStyle(.plain)
        }
    }

    private func sideLine(_ competitor: Competitor) -> some View {
        HStack(spacing: Spacing.sm) {
            LogoImage(url: competitor.team.logoURL)
                .frame(width: logoSize, height: logoSize)
            Text(competitor.team.location)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            if let rank = competitor.rank {
                Text("\(rank)")
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            if let record = competitor.record {
                Text(record)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var statusColumn: some View {
        if case .live = game.status {
            HStack(spacing: Spacing.xs) {
                LiveDot()
                Text("\(game.away.score.map(String.init) ?? "–")-\(game.home.score.map(String.init) ?? "–")")
                    .font(.scoreLive)
                    .foregroundStyle(.textPrimary)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                if let date = game.date {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).month(.defaultDigits).day()))
                        .font(.metaMedium)
                        .foregroundStyle(.textPrimary)
                    // An unannounced kickoff carries a placeholder midnight
                    // date — "TBD" over a lying "12:00 AM".
                    Text(game.timeTBD ? "TBD" : date.formatted(.dateTime.hour().minute()))
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                }
                if let broadcast = game.broadcast {
                    Text(broadcast)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    /// One spoken sentence: "Michigan at Ohio State, Saturday, September
    /// 13, 7:00 PM, on Peacock" — or the live line while in progress.
    private var accessibilitySummary: String {
        var parts = ["\(game.away.team.location) at \(game.home.team.location)"]
        if case .live = game.status {
            parts.append("live, \(game.away.score.map(String.init) ?? "no score") to \(game.home.score.map(String.init) ?? "no score")")
        } else if let date = game.date {
            parts.append(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            parts.append(game.timeTBD ? "kickoff time to be determined"
                         : date.formatted(.dateTime.hour().minute()))
            if let broadcast = game.broadcast {
                parts.append("on \(broadcast)")
            }
        }
        return parts.joined(separator: ", ")
    }
}
