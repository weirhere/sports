import SwiftUI

/// One game, one compact row. Two stacked team lines (away over home, the
/// CFB convention) with a trailing score/status column. Pre and final rows
/// stay quiet; live rows spend the visual budget.
///
/// At accessibility text sizes the side-by-side split stops paying: the
/// trailing column keeps its width and the names are left with a character
/// and an ellipsis. So the row reflows to one column — each team line carries
/// its own score, and the status drops to a line of its own underneath.
struct GameRow: View {
    let game: Game
    /// True when a day divider directly above the row already names the date,
    /// in which case the row doesn't repeat it. VoiceOver still hears the full
    /// date either way — a swipe can land on the row without the divider.
    var dayIsLabeled: Bool = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var rankWidth: CGFloat = 14

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if isStacked { stackedBody } else { compactBody }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        // The row reads as one sentence — "Georgia 24, Tennessee 17, 3rd
        // quarter" — instead of a dozen fragments. Logos and layout stay
        // visual-only, and the spoken label is identical in both layouts.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Compact layout (default text sizes)

    private var compactBody: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                teamLine(game.away)
                teamLine(game.home)
            }
            // Team names win the width fight with the trailing column —
            // "New Mexico State" beats a broadcast string's elbow room. The
            // kick time is the one exception: it's short, load-bearing, and
            // pinned to its natural width (see `trailing`).
            .layoutPriority(1)
            Spacer(minLength: Spacing.sm)
            trailing
        }
    }

    // MARK: - Stacked layout (accessibility text sizes)

    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            stackedTeamLine(game.away)
            stackedTeamLine(game.home)
            stackedStatus
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Name and score share a line here, so the matchup still reads down the
    /// left edge the way it does in the compact row.
    private func stackedTeamLine(_ competitor: Competitor) -> some View {
        HStack(spacing: Spacing.sm) {
            teamLine(competitor)
            Spacer(minLength: Spacing.sm)
            if showsScores {
                scoreText(competitor, font: scoreFont)
            }
        }
    }

    @ViewBuilder
    private var stackedStatus: some View {
        switch game.status {
        case .pre:
            // Kick time and network ride one line while they fit; past that
            // they stack, rather than the network truncating away.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) {
                    kickTimeText
                    if let network {
                        Text("·").font(.meta).foregroundStyle(.textSecondary)
                        networkText(network)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    kickTimeText
                    if let network { networkText(network) }
                }
            }
        case .live(let displayClock, let period, _, _):
            HStack(spacing: Spacing.sm) {
                LiveDot()
                Text(liveDetail(clock: displayClock, period: period))
                    .font(.metaEmphasis)
                    .foregroundStyle(.textPrimary)
            }
        case .final(let detail):
            Text(finalLabel(detail))
                .font(.metaEmphasis)
                .foregroundStyle(.textSecondary)
        case .other(let detail):
            Text(detail ?? "—")
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
    }

    // MARK: - Team line

    private func teamLine(_ competitor: Competitor) -> some View {
        HStack(spacing: 6) {
            if let rank = competitor.rank {
                Text("\(rank)")
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
                    .frame(minWidth: rankWidth, alignment: .trailing)
            }
            logo(competitor.team)
            Text(competitor.team.location)
                .font(emphasize(competitor) ? .teamNameEmphasis : .teamName)
                .foregroundStyle(mute(competitor) ? .textSecondary : .textPrimary)
                // The stacked row has a full line to spend, so a long name
                // wraps instead of truncating.
                .lineLimit(isStacked ? 2 : 1)
            if hasPossession(competitor) {
                Image(systemName: "football.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.textSecondary)
            }
            if let record = competitor.record, case .pre = game.status {
                Text(record)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
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
                kickTimeText
                    // "Sat, 9/5 3:30 PM" is wide enough to wrap a character
                    // per line under the names' layout priority at large text
                    // sizes. The time holds its natural width instead.
                    .fixedSize(horizontal: true, vertical: false)
                if let network { networkText(network) }
            }
        case .live(let displayClock, let period, _, _):
            HStack(spacing: Spacing.md) {
                scoreColumn(font: .scoreLive)
                VStack(alignment: .leading, spacing: 3) {
                    LiveDot()
                    Text(liveDetail(clock: displayClock, period: period))
                        .font(.metaEmphasis)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(minWidth: 52, alignment: .leading)
            }
        case .final(let detail):
            HStack(spacing: Spacing.md) {
                scoreColumn(font: .score)
                Text(finalLabel(detail))
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 52, alignment: .leading)
            }
        case .other(let detail):
            Text(detail ?? "—")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .frame(minWidth: 52, alignment: .trailing)
        }
    }

    private var kickTimeText: some View {
        Text(kickTime)
            .font(.meta)
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
    }

    private func networkText(_ network: String) -> some View {
        Text(network)
            .font(.metaEmphasis)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
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

    /// Pre and unscheduled rows have no numbers to show yet.
    private var showsScores: Bool {
        switch game.status {
        case .live, .final: true
        case .pre, .other: false
        }
    }

    private var scoreFont: Font {
        if case .live = game.status { return .scoreLive }
        return .score
    }

    /// First network only: "ESPN Unlmtd/The CW Network" otherwise swallows
    /// the row.
    private var network: String? {
        guard let broadcast = game.broadcast else { return nil }
        return broadcast.split(separator: "/").first.map(String.init) ?? broadcast
    }

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
        return Self.relativeKick(date, weekday: .abbreviated, includeDate: !dayIsLabeled)
    }

    /// How far out the kick is decides how much of the date the row spends:
    /// "Today 3:30 PM" inside the 48 hours that matter, the bare weekday out
    /// to a week, and the weekday plus a date past that — because "Sat" only
    /// ever means *this* Saturday. Shared with the VoiceOver sentence, which
    /// asks for the wide weekday.
    ///
    /// `includeDate` is how a caller says the date is already on screen just
    /// above; the ladder then tops out at the weekday rather than repeating it.
    ///
    /// One day-granularity difference drives every branch, so a noon kick and
    /// an 11pm kick are equally far away. `now`/`calendar` are injected so the
    /// thresholds are testable without freezing the clock.
    static func relativeKick(_ date: Date,
                             weekday: Date.FormatStyle.Symbol.Weekday,
                             includeDate: Bool = true,
                             now: Date = .now,
                             calendar: Calendar = .current) -> String {
        let time = date.formatted(.dateTime.hour().minute())
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "Today \(time)"
        case 1: return "Tomorrow \(time)"
        case ..<7: return "\(date.formatted(.dateTime.weekday(weekday))) \(time)"
        default:
            let style = Date.FormatStyle.dateTime.weekday(weekday)
            let day = includeDate ? style.month(.defaultDigits).day() : style
            return "\(date.formatted(day)) \(time)"
        }
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
                parts.append(Self.relativeKick(date, weekday: .wide))
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

#Preview("Accessibility XL") {
    let ncState = Team(id: "152", location: "North Carolina State", name: "Wolfpack",
                       abbreviation: "NCST", displayName: "NC State Wolfpack",
                       shortDisplayName: "NC State", logoURL: nil, conferenceId: 1)
    let tcu = Team(id: "2628", location: "TCU", name: "Horned Frogs", abbreviation: "TCU",
                   displayName: "TCU Horned Frogs", shortDisplayName: "TCU",
                   logoURL: nil, conferenceId: 4)
    return VStack(spacing: 0) {
        GameRow(game: Game(
            id: "1", date: .now.addingTimeInterval(86_400), name: nil, shortName: "TCU @ NCST",
            weekNumber: 5, status: .pre(detail: nil),
            home: Competitor(team: ncState, score: nil, record: "4-1", rank: nil, isHome: true, winner: nil),
            away: Competitor(team: tcu, score: nil, record: "5-0", rank: 9, isHome: false, winner: nil),
            broadcast: "ESPN"))
        Divider().overlay(Color.divider)
        GameRow(game: Game(
            id: "2", date: .now, name: nil, shortName: "TCU @ NCST", weekNumber: 5,
            status: .live(displayClock: "5:24", period: 3, detail: nil, possessionTeamId: "2628"),
            home: Competitor(team: ncState, score: 17, record: "4-1", rank: nil, isHome: true, winner: nil),
            away: Competitor(team: tcu, score: 24, record: "5-0", rank: 9, isHome: false, winner: nil),
            broadcast: "ESPN"))
    }
    .background(Color.bgPrimary)
    .environment(\.dynamicTypeSize, .accessibility3)
}
