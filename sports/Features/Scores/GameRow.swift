import SwiftUI

/// One game, one compact row. Two stacked team lines (away over home, the
/// CFB convention) with a trailing score/status column. Pre and final rows
/// stay quiet; live rows spend the visual budget.
struct GameRow: View {
    let game: Game

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                teamLine(game.away)
                teamLine(game.home)
            }
            // Team names win the width fight with the trailing column —
            // "New Mexico State" beats a broadcast string's elbow room.
            .layoutPriority(1)
            Spacer(minLength: Spacing.sm)
            trailing
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        // The row reads as one sentence — "Georgia 24, Tennessee 17, 3rd
        // quarter" — instead of a dozen fragments. Logos and layout stay
        // visual-only.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Team line

    private func teamLine(_ competitor: Competitor) -> some View {
        HStack(spacing: 6) {
            if let rank = competitor.rank {
                Text("\(rank)")
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
                    .frame(minWidth: 14, alignment: .trailing)
            }
            logo(competitor.team)
            Text(competitor.team.location)
                .font(emphasize(competitor) ? .teamNameEmphasis : .teamName)
                .foregroundStyle(mute(competitor) ? .textSecondary : .textPrimary)
                .lineLimit(1)
            if hasPossession(competitor) {
                Image(systemName: "football.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.textSecondary)
            }
            if let record = competitor.record, case .pre = game.status {
                Text(record)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private func logo(_ team: Team) -> some View {
        LogoImage(url: team.logoURL)
            .frame(width: logoSize, height: logoSize)
    }

    // MARK: - Trailing column

    @ViewBuilder
    private var trailing: some View {
        switch game.status {
        case .pre:
            VStack(alignment: .trailing, spacing: 2) {
                Text(kickTime)
                    .font(.meta)
                    .foregroundStyle(.textPrimary)
                if let broadcast = game.broadcast {
                    // First network only: "ESPN Unlmtd/The CW Network"
                    // otherwise swallows the row.
                    Text(broadcast.split(separator: "/").first.map(String.init) ?? broadcast)
                        .font(.metaEmphasis)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            }
        case .live(let displayClock, let period, _, _):
            HStack(spacing: Spacing.md) {
                scoreColumn(font: .scoreLive)
                VStack(alignment: .leading, spacing: 3) {
                    LiveDot()
                    Text(liveDetail(clock: displayClock, period: period))
                        .font(.metaEmphasis)
                        .foregroundStyle(.textPrimary)
                }
                .frame(minWidth: 52, alignment: .leading)
            }
        case .final(let detail):
            HStack(spacing: Spacing.md) {
                scoreColumn(font: .score)
                Text(finalLabel(detail))
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
                    .frame(minWidth: 52, alignment: .leading)
            }
        case .other(let detail):
            Text(detail ?? "—")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .frame(minWidth: 52, alignment: .trailing)
        }
    }

    private func scoreColumn(font: Font) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            scoreText(game.away, font: font)
            scoreText(game.home, font: font)
        }
    }

    private func scoreText(_ competitor: Competitor, font: Font) -> some View {
        Text(competitor.score.map(String.init) ?? "–")
            .font(mute(competitor) ? .scoreMuted : font)
            .foregroundStyle(mute(competitor) ? .textSecondary : .textPrimary)
    }

    // MARK: - Status helpers

    /// Final rows put the winner in heavier type; live rows emphasize both.
    private func emphasize(_ competitor: Competitor) -> Bool {
        switch game.status {
        case .live: true
        case .final: competitor.winner == true
        default: false
        }
    }

    /// The loser of a final fades to secondary; if ESPN omits the winner
    /// flag, nobody fades.
    private func mute(_ competitor: Competitor) -> Bool {
        if case .final = game.status {
            return otherSide(of: competitor).winner == true
        }
        return false
    }

    private func otherSide(of competitor: Competitor) -> Competitor {
        competitor.isHome ? game.away : game.home
    }

    private func hasPossession(_ competitor: Competitor) -> Bool {
        if case .live(_, _, _, let possessionTeamId) = game.status {
            return possessionTeamId == competitor.team.id
        }
        return false
    }

    private var kickTime: String {
        guard let date = game.date else { return "TBD" }
        return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private func liveDetail(clock: String?, period: Int?) -> String {
        let quarter = period.map { $0 <= 4 ? "Q\($0)" : ($0 == 5 ? "OT" : "\($0 - 4)OT") }
        return [quarter, clock].compactMap(\.self).joined(separator: " ")
    }

    private func finalLabel(_ detail: String?) -> String {
        if let detail, detail.localizedCaseInsensitiveContains("OT") { return "FINAL OT" }
        return "FINAL"
    }

    // MARK: - VoiceOver
    // Internal, not private, so the label shapes are unit-testable.

    var accessibilitySummary: String {
        switch game.status {
        case .pre:
            func side(_ competitor: Competitor) -> String {
                [sideName(competitor), spokenRecord(competitor)].compactMap(\.self).joined(separator: " ")
            }
            var parts = ["\(side(game.away)) at \(side(game.home))"]
            if let date = game.date {
                parts.append(date.formatted(.dateTime.weekday(.wide).hour().minute()))
            }
            if let broadcast = game.broadcast { parts.append("on \(broadcast)") }
            return parts.joined(separator: ", ")
        case .live(let clock, let period, _, let possessionTeamId):
            var parts = [scoreSummary]
            if let period { parts.append(spokenPeriod(period)) }
            if let clock { parts.append("\(clock) left") }
            if let possessionTeamId,
               let holder = [game.away, game.home].first(where: { $0.team.id == possessionTeamId }) {
                parts.append("\(holder.team.location) has the ball")
            }
            return parts.joined(separator: ", ")
        case .final(let detail):
            let overtime = detail?.localizedCaseInsensitiveContains("OT") == true
            return "\(scoreSummary), \(overtime ? "final, overtime" : "final")"
        case .other(let detail):
            return "\(sideName(game.away)) at \(sideName(game.home)), \(detail ?? "status unavailable")"
        }
    }

    private func sideName(_ competitor: Competitor) -> String {
        guard let rank = competitor.rank else { return competitor.team.location }
        return "number \(rank) \(competitor.team.location)"
    }

    /// "5-0" reads as "5 and 0", the spoken convention, not "5 minus 0".
    private func spokenRecord(_ competitor: Competitor) -> String? {
        competitor.record.map { $0.replacingOccurrences(of: "-", with: " and ") }
    }

    private var scoreSummary: String {
        "\(sideName(game.away)) \(game.away.score.map(String.init) ?? "no score"), "
            + "\(sideName(game.home)) \(game.home.score.map(String.init) ?? "no score")"
    }

    private func spokenPeriod(_ period: Int) -> String {
        switch period {
        case 1: "1st quarter"
        case 2: "2nd quarter"
        case 3: "3rd quarter"
        case 4: "4th quarter"
        case 5: "overtime"
        default: "overtime \(period - 4)"
        }
    }
}

// MARK: - Previews

#Preview("Variants") {
    let georgia = Team(id: "61", location: "Georgia", name: "Bulldogs", abbreviation: "UGA",
                       displayName: "Georgia Bulldogs", shortDisplayName: "Georgia",
                       logoURL: nil, conferenceId: 8)
    let tennessee = Team(id: "2633", location: "Tennessee", name: "Volunteers", abbreviation: "TENN",
                         displayName: "Tennessee Volunteers", shortDisplayName: "Tennessee",
                         logoURL: nil, conferenceId: 8)
    return VStack(spacing: 0) {
        GameRow(game: Game(
            id: "1", date: .now.addingTimeInterval(86_400), name: nil, shortName: "UGA @ TENN",
            weekNumber: 5,
            status: .pre(detail: nil),
            home: Competitor(team: tennessee, score: nil, record: "4-1", rank: 12, isHome: true, winner: nil),
            away: Competitor(team: georgia, score: nil, record: "5-0", rank: 3, isHome: false, winner: nil),
            broadcast: "ESPN"))
        Divider().overlay(Color.divider)
        GameRow(game: Game(
            id: "2", date: .now, name: nil, shortName: "UGA @ TENN", weekNumber: 5,
            status: .live(displayClock: "5:24", period: 3, detail: nil, possessionTeamId: "61"),
            home: Competitor(team: tennessee, score: 17, record: "4-1", rank: 12, isHome: true, winner: nil),
            away: Competitor(team: georgia, score: 24, record: "5-0", rank: 3, isHome: false, winner: nil),
            broadcast: "ESPN"))
        Divider().overlay(Color.divider)
        GameRow(game: Game(
            id: "3", date: .now, name: nil, shortName: "UGA @ TENN", weekNumber: 5,
            status: .final(detail: "Final"),
            home: Competitor(team: tennessee, score: 17, record: "4-2", rank: 12, isHome: true, winner: false),
            away: Competitor(team: georgia, score: 24, record: "6-0", rank: 3, isHome: false, winner: true),
            broadcast: nil))
    }
    .background(Color.bgPrimary)
}
