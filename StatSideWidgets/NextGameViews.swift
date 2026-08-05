import SwiftUI
import WidgetKit

/// Routes an entry to its family-specific layout. Same design language as
/// the app's game rows: monochrome chrome, logos in color, red only on live.
struct NextGameWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextGameEntry

    var body: some View {
        switch entry.state {
        case .noFollows:
            EmptyStateView(title: "Follow your teams",
                           subtitle: "Pick teams in StatSide and their games live here.")
                .widgetURL(URL(string: "statside://teams"))
        case .noGames:
            EmptyStateView(title: "No games this week",
                           subtitle: "Your teams' next kickoff will show up here.")
        case .games(let games, let stale):
            switch family {
            case .accessoryRectangular:
                AccessoryGameView(game: games[0])
                    .widgetURL(games[0].deepLink)
            case .systemMedium:
                MediumGamesView(games: games, stale: stale, asOf: entry.date)
            default:
                SmallGameView(game: games[0], stale: stale, asOf: entry.date)
                    .widgetURL(games[0].deepLink)
            }
        }
    }
}

// MARK: - Small

struct SmallGameView: View {
    let game: WidgetGame
    let stale: Bool
    let asOf: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetTeamRow(line: game.away, emphasize: game.isLive)
            WidgetTeamRow(line: game.home, emphasize: game.isLive)
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                if game.isLive {
                    Circle()
                        .fill(Color.liveAccent)
                        .frame(width: 6, height: 6)
                }
                Text(game.statusLine)
                    .font(.metaEmphasis)
                    .foregroundStyle(game.isLive ? .textPrimary : .textSecondary)
                    .lineLimit(1)
                if stale {
                    StaleMarker(asOf: asOf)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Medium

struct MediumGamesView: View {
    let games: [WidgetGame]
    let stale: Bool
    let asOf: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(games.prefix(3)) { game in
                Link(destination: game.deepLink ?? URL(string: "statside://teams")!) {
                    MediumGameRow(game: game)
                }
                if game.id != games.prefix(3).last?.id {
                    Divider().overlay(Color.divider)
                }
            }
            if stale {
                StaleMarker(asOf: asOf)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct MediumGameRow: View {
    let game: WidgetGame

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetTeamRow(line: game.away, emphasize: game.isLive, showScore: false)
                WidgetTeamRow(line: game.home, emphasize: game.isLive, showScore: false)
            }
            .layoutPriority(1)
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 4) {
                WidgetScoreText(line: game.away, emphasize: game.isLive)
                WidgetScoreText(line: game.home, emphasize: game.isLive)
            }
            HStack(spacing: 5) {
                if game.isLive {
                    Circle()
                        .fill(Color.liveAccent)
                        .frame(width: 6, height: 6)
                }
                Text(game.statusLine)
                    .font(.metaEmphasis)
                    .foregroundStyle(game.isLive ? .textPrimary : .textSecondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 56, alignment: .leading)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Lock screen

struct AccessoryGameView: View {
    let game: WidgetGame

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if game.away.score != nil || game.home.score != nil {
                Text("\(game.away.abbreviation) \(game.away.score.map(String.init) ?? "–")")
                    .font(.headline.monospacedDigit())
                Text("\(game.home.abbreviation) \(game.home.score.map(String.init) ?? "–")")
                    .font(.headline.monospacedDigit())
            } else {
                Text("\(game.away.abbreviation) vs \(game.home.abbreviation)")
                    .font(.headline)
            }
            Text(game.statusLine)
                .font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shared pieces

struct WidgetTeamRow: View {
    let line: WidgetTeamLine
    let emphasize: Bool
    var showScore = true

    var body: some View {
        HStack(spacing: 6) {
            logo
            if let rank = line.rank {
                Text("\(rank)")
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
            }
            Text(line.abbreviation)
                .font(emphasize ? .teamNameEmphasis : .teamName)
                .foregroundStyle(line.muted ? .textSecondary : .textPrimary)
                .lineLimit(1)
            if showScore {
                Spacer(minLength: Spacing.xs)
                WidgetScoreText(line: line, emphasize: emphasize)
            }
        }
    }

    @ViewBuilder
    private var logo: some View {
        if let image = line.logo {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        } else {
            Circle()
                .fill(Color.bgElevated)
                .frame(width: 20, height: 20)
        }
    }
}

struct WidgetScoreText: View {
    let line: WidgetTeamLine
    let emphasize: Bool

    var body: some View {
        Text(line.score.map(String.init) ?? "–")
            .font(line.muted ? .scoreMuted : (emphasize ? .scoreLive : .score))
            .foregroundStyle(line.muted ? .textSecondary : .textPrimary)
    }
}

/// Honest-not-wrong: a failed refresh re-serves the last snapshot with a
/// quiet timestamp instead of pretending it's current.
struct StaleMarker: View {
    let asOf: Date

    var body: some View {
        Text("as of \(asOf.formatted(.dateTime.hour().minute()))")
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            Text(subtitle)
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
