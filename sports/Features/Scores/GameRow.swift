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
    /// True inside a day-grouped section, whose accordion header names the
    /// whole day — the row spends nothing on the date, just kick time and
    /// network. VoiceOver still hears the full date.
    var timeOnly: Bool = false
    /// Set only where a section mixes leagues — the Following section, which
    /// stays cross-league. Everywhere else the league is already the screen's
    /// scope, so a tag on every row would be noise saying what the header
    /// above it already said.
    var leagueTag: League? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 28
    @ScaledMetric(relativeTo: .subheadline) private var logoSlot: CGFloat = 32
    @ScaledMetric(relativeTo: .caption2) private var statusWidth: CGFloat = 80

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if isStacked { stackedBody } else { compactBody }
        }
        .padding(Spacing.lg)
        .contentShape(Rectangle())
        // The row reads as one sentence — "Georgia 24, Tennessee 17, 3rd
        // quarter" — instead of a dozen fragments. Logos and layout stay
        // visual-only, and the spoken label is identical in both layouts.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    /// The league leads the sentence where a section mixes them — "NFL,
    /// Cleveland at Jacksonville…" — so VoiceOver gets what the tag gives
    /// a sighted reader. Internal, like `accessibilitySummary`, so the
    /// label shape is unit-testable.
    var spokenLabel: String {
        guard let leagueTag else { return accessibilitySummary }
        return "\(leagueTag.displayName), \(accessibilitySummary)"
    }

    // MARK: - Compact layout (default text sizes)
    // The 2240-spec matchup shape: two team rows (name, rank after it,
    // record or score at the trailing edge), a hairline column divider,
    // then the fixed status column.

    private var compactBody: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                teamRow(game.away)
                teamRow(game.home)
            }
            Rectangle()
                .fill(Color.divider)
                .frame(width: 1, height: 55)
            statusColumn
                .frame(width: statusWidth, alignment: .leading)
        }
    }

    private func teamRow(_ competitor: Competitor) -> some View {
        HStack(spacing: Spacing.sm) {
            teamIdentity(competitor)
            Spacer(minLength: Spacing.sm)
            switch game.status {
            case .pre:
                // The record is upcoming-only information — a final row's
                // trailing edge belongs to the score alone.
                if let record = competitor.record {
                    Text(record)
                        .font(.rowMetaMedium)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            case .live, .final:
                scoreText(competitor, font: scoreFont)
            case .other:
                EmptyView()
            }
        }
    }

    /// Logo, name, rank after it (the 2240 spec), possession.
    private func teamIdentity(_ competitor: Competitor) -> some View {
        HStack(spacing: Spacing.sm) {
            logo(competitor.team)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(competitor.team.location)
                    .font(emphasize(competitor) ? .rowNameEmphasis : .rowName)
                    .foregroundStyle(mute(competitor) ? .textSecondary : .textPrimary)
                    // The stacked row has a full line to spend, so a long
                    // name wraps instead of truncating.
                    .lineLimit(isStacked ? 2 : 1)
                if let rank = competitor.rank {
                    Text("\(rank)")
                        .font(.rowMeta)
                        .foregroundStyle(mute(competitor) ? .textSecondary : .textPrimary)
                }
            }
            if hasPossession(competitor) {
                Image(systemName: "football.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.textSecondary)
            }
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
            teamIdentity(competitor)
            if case .pre = game.status, let record = competitor.record {
                Text(record)
                    .font(.rowMetaMedium)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
            if showsScores {
                scoreText(competitor, font: scoreFont)
            }
        }
    }

    @ViewBuilder
    private var stackedStatus: some View {
        VStack(alignment: .leading, spacing: 2) {
            leagueTagText
            stackedStatusLines
        }
    }

    @ViewBuilder
    private var stackedStatusLines: some View {
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
        case .live:
            // Clock and network ride one line while they fit, then stack —
            // the same treatment as the pre-game kick line above.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) {
                    liveClockLine
                    if let network {
                        Text("·").font(.meta).foregroundStyle(.textSecondary)
                        networkText(network)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    liveClockLine
                    if let network { networkText(network) }
                }
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

    private func logo(_ team: Team) -> some View {
        LogoImage(url: team.logoURL)
            .frame(width: logoSize, height: logoSize)
            .frame(width: logoSlot, height: logoSlot)
    }

    // MARK: - Status column
    // The fixed right column across the hairline: what the game needs from
    // you now — kick day/time + network, the live line, or Final + date.

    @ViewBuilder
    private var statusColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            leagueTagText
            statusLines
        }
    }

    /// Quiet, uppercase, and above the status — the column's own caption.
    /// Chrome, so it stays monochrome; the team marks beside it are the
    /// colour that tells you which sport this is at a glance anyway.
    @ViewBuilder
    private var leagueTagText: some View {
        if let leagueTag {
            Text(leagueTag.shortName)
                .font(.rowMeta)
                .tracking(0.4)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var statusLines: some View {
        switch game.status {
        case .pre:
            VStack(alignment: .leading, spacing: 2) {
                if let date = game.date {
                    if timeOnly {
                        // A day section's header names the day; the row
                        // spends its lines on time and network only.
                        Text(game.timeTBD ? "TBD" : date.formatted(.dateTime.hour().minute()))
                            .font(.rowMetaMedium)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                    } else {
                        let kick = Self.relativeKickParts(date, weekday: .abbreviated,
                                                          timeTBD: game.timeTBD)
                        Text(kick.day)
                            .font(.rowMetaMedium)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                        Text(kick.time)
                            .font(.rowMeta)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("TBD")
                        .font(.rowMetaMedium)
                        .foregroundStyle(.textPrimary)
                }
                if let network {
                    Text(network)
                        .font(.rowMeta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            }
        case .live:
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Spacing.xs) {
                    LiveDot()
                    Text(game.status.liveStatusText ?? "Live")
                        .font(.rowMetaMedium)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                }
                // "Where do I watch" is the live row's second question —
                // the widget's pre+live rule, adopted app-side (2026-08-29).
                if let network {
                    Text(network)
                        .font(.rowMeta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            }
        case .final(let detail):
            VStack(alignment: .leading, spacing: 2) {
                Text(finalLabel(detail))
                    .font(.rowMetaMedium)
                    .foregroundStyle(.textPrimary)
                if let date = game.date, !timeOnly {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).month(.defaultDigits).day()))
                        .font(.rowMeta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            }
        case .other(let detail):
            Text(detail ?? "—")
                .font(.rowMeta)
                .foregroundStyle(.textSecondary)
        }
    }

    private var kickTimeText: some View {
        kickText(kickTime)
    }

    private func kickText(_ string: String) -> some View {
        Text(string)
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

    private var liveClockLine: some View {
        HStack(spacing: Spacing.sm) {
            LiveDot()
            Text(game.status.liveStatusText ?? "Live")
                .font(.metaEmphasis)
                .foregroundStyle(.textPrimary)
        }
    }

    private func scoreText(_ competitor: Competitor, font: Font) -> some View {
        Text(competitor.score.map(String.init) ?? "–")
            .font(mute(competitor) ? .rowName.monospacedDigit() : font)
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
        // Live spends weight, per the budget — semibold at the row scale.
        if case .live = game.status { return .rowNameEmphasis.monospacedDigit() }
        return .rowName.monospacedDigit()
    }

    /// First network only: "ESPN Unlmtd/The CW Network" otherwise swallows
    /// the row.
    private var network: String? { game.primaryBroadcast }

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
        if case .live(_, _, _, _, let possessionTeamId) = game.status {
            return possessionTeamId == competitor.team.id
        }
        return false
    }

    private var kickTime: String {
        guard let date = game.date else { return "TBD" }
        if timeOnly { return game.timeTBD ? "TBD" : date.formatted(.dateTime.hour().minute()) }
        return Self.relativeKick(date, weekday: .abbreviated, timeTBD: game.timeTBD)
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
    ///
    /// The day and time come back separately because the trailing column gives
    /// them a line each; flowing contexts join them with `relativeKick`.
    ///
    /// `timeTBD` keeps the day ladder (the placeholder date's day is real)
    /// but swaps the clock time for "TBD".
    static func relativeKickParts(_ date: Date,
                                  weekday: Date.FormatStyle.Symbol.Weekday,
                                  timeTBD: Bool = false,
                                  includeDate: Bool = true,
                                  now: Date = .now,
                                  calendar: Calendar = .current) -> (day: String, time: String) {
        let time = timeTBD ? "TBD" : date.formatted(.dateTime.hour().minute())
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return ("Today", time)
        case 1: return ("Tomorrow", time)
        default:
            // Weekday + date from two days out — with the in-section day
            // dividers gone (Andy, 2026-08-25), the row's own day line is
            // the only date on screen, and a bare "Sat" is ambiguous in a
            // two-weekend week (2026's Week 1).
            let style = Date.FormatStyle.dateTime.weekday(weekday)
            let day = includeDate ? style.month(.defaultDigits).day() : style
            return (date.formatted(day), time)
        }
    }

    /// The parts as one phrase, for the VoiceOver sentence and the stacked
    /// layout's flowing status line.
    static func relativeKick(_ date: Date,
                             weekday: Date.FormatStyle.Symbol.Weekday,
                             timeTBD: Bool = false,
                             includeDate: Bool = true,
                             now: Date = .now,
                             calendar: Calendar = .current) -> String {
        let kick = relativeKickParts(date, weekday: weekday, timeTBD: timeTBD,
                                     includeDate: includeDate, now: now, calendar: calendar)
        return "\(kick.day) \(kick.time)"
    }

    private func finalLabel(_ detail: String?) -> String {
        // Sentence case per the 2240 spec.
        if let detail, detail.localizedCaseInsensitiveContains("OT") { return "Final OT" }
        return "Final"
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
                if game.timeTBD {
                    parts.append("\(Self.relativeKickParts(date, weekday: .wide).day), kickoff time to be determined")
                } else {
                    parts.append(Self.relativeKick(date, weekday: .wide))
                }
            }
            if let broadcast = game.broadcast { parts.append("on \(broadcast)") }
            return parts.joined(separator: ", ")
        case .live(let clock, let period, _, let phase, let possessionTeamId):
            var parts = [scoreSummary]
            switch phase {
            case .halftime:
                parts.append("halftime")
            case .endOfPeriod:
                if let period { parts.append("end of \(spokenPeriod(period))") }
            case .playing:
                if let period { parts.append(spokenPeriod(period)) }
                if let clock { parts.append("\(clock) left") }
            }
            if let possessionTeamId,
               let holder = [game.away, game.home].first(where: { $0.team.id == possessionTeamId }) {
                parts.append("\(holder.team.location) has the ball")
            }
            if let broadcast = game.broadcast { parts.append("on \(broadcast)") }
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
            status: .live(displayClock: "5:24", period: 3, detail: nil, phase: .playing, possessionTeamId: "61"),
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
    .background(Color.bgCard)
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
            status: .live(displayClock: "5:24", period: 3, detail: nil, phase: .playing, possessionTeamId: "2628"),
            home: Competitor(team: ncState, score: 17, record: "4-1", rank: nil, isHome: true, winner: nil),
            away: Competitor(team: tcu, score: 24, record: "5-0", rank: 9, isHome: false, winner: nil),
            broadcast: "ESPN"))
    }
    .background(Color.bgCard)
    .environment(\.dynamicTypeSize, .accessibility3)
}
