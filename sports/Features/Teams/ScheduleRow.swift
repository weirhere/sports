import SwiftUI

/// One game on a team page, from that team's perspective:
/// date · vs/@ opponent · result or kick time.
struct ScheduleRow: View {
    let game: Game
    let teamId: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var dateWidth: CGFloat = 52

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if isStacked { stackedBody } else { compactBody }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var compactBody: some View {
        HStack(spacing: Spacing.md) {
            dateText
                .frame(minWidth: dateWidth, alignment: .leading)
            matchup
            Spacer()
            trailing
        }
    }

    /// The date moves to its own line above the matchup; four columns don't
    /// survive accessibility sizes on a phone.
    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            dateText
            HStack(spacing: Spacing.sm) {
                matchup
                Spacer(minLength: Spacing.sm)
                trailing
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateText: some View {
        Text(game.date?.formatted(.dateTime.month(.abbreviated).day()) ?? "TBD")
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var matchup: some View {
        HStack(spacing: Spacing.sm) {
            Text(isHome ? "vs" : "@")
                .font(.meta)
                .foregroundStyle(.textSecondary)
            LogoImage(url: opponent.team.logoURL)
                .frame(width: logoSize, height: logoSize)
            Text(opponent.team.location)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(isStacked ? 2 : 1)
        }
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
            parts.append(mine.score != nil || opponent.score != nil
                         ? "live, \(spokenScore)" : "live now")
        case .pre:
            if game.timeTBD {
                parts.append("kickoff time to be determined")
            } else if let date = game.date {
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
            // The P1 review's result chip: green for a win, red for a loss
            // (the budget's existing movement pair), the score itself in
            // mine-first order so color is never the only signal. bgPrimary
            // ink inverts with the scheme, keeping contrast on the bright
            // dark-mode greens/reds.
            let won = mine.winner == true
            let lost = opponent.winner == true
            Text("\(mine.score.map(String.init) ?? "–")-\(opponent.score.map(String.init) ?? "–")")
                .font(.chipEmphasis.monospacedDigit())
                .foregroundStyle(won || lost ? Color.bgPrimary : .textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(won ? Color.rankUp : (lost ? Color.rankDown : Color.bgElevated))
                )
        case .live:
            // The dot alone — the Current game card above carries the
            // score (Andy, 2026-08-29). VoiceOver still speaks it.
            LiveDot()
        case .pre:
            // An unannounced kickoff carries a placeholder midnight date —
            // "TBD" over a lying "12:00 AM".
            Text(game.timeTBD ? "TBD" : game.date?.formatted(.dateTime.hour().minute()) ?? "TBD")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                // Kick time holds its natural width; the opponent name
                // wraps or truncates instead of the clock breaking apart.
                .fixedSize(horizontal: true, vertical: false)
        case .other(let detail):
            Text(detail ?? "—")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }
}
