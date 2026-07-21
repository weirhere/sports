import SwiftUI

/// One game on a team page, from that team's perspective:
/// date · vs/@ opponent · result or kick time.
struct ScheduleRow: View {
    let game: Game
    let teamId: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(game.date?.formatted(.dateTime.month(.abbreviated).day()) ?? "TBD")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text(isHome ? "vs" : "@")
                .font(.meta)
                .foregroundStyle(.textSecondary)
            AsyncImage(url: opponent.team.logoURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Circle().fill(Color.bgElevated)
            }
            .frame(width: 20, height: 20)
            Text(opponent.team.location)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            Spacer()
            trailing
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
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
