import SwiftUI

/// One game, one compact row. Two stacked team lines (away over home, the
/// CFB convention) with a trailing score/status column. Pre and final rows
/// stay quiet; live rows spend the visual budget.
struct GameRow: View {
    let game: Game

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                teamLine(game.away)
                teamLine(game.home)
            }
            Spacer(minLength: Spacing.sm)
            trailing
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
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
        AsyncImage(url: team.logoURL) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Circle().fill(Color.bgElevated)
        }
        .frame(width: 20, height: 20)
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
                    Text(broadcast)
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
        VStack(alignment: .trailing, spacing: 3) {
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
