import SwiftUI

/// The Games tab: one row per appearance — when, who against, how it ended,
/// and that night's line for this player (E20's Games row, 2026-09-20).
///
/// Grouped the way ESPN's log is — regular season and postseason — and
/// labelled the way the app labels time per league: football by week,
/// basketball and hockey by date, because ESPN sends `week: null` for both
/// (principle 2). Every row pushes the game page it names.
struct PlayerGamesList: View {
    let log: PlayerGameLog
    let league: League
    /// The player's own stat category ("passing", "averages"), which picks
    /// the row's headline columns.
    let category: String?

    @Environment(TeamDirectoryStore.self) private var directory

    /// Room for "Wk 15" and "Dec 14", the two things this column says.
    private static let whenWidth: CGFloat = 44

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(log.sections) { section in
                VStack(spacing: 0) {
                    CardHeader(title: section.title, subtitle: "\(section.entries.count) games")
                    ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry)
                        if index < section.entries.count - 1 {
                            Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                        }
                    }
                }
                .cardSurface()
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: PlayerGameLog.Entry) -> some View {
        if let game = game(for: entry) {
            NavigationLink(value: game) { rowContent(entry, isLink: true) }
                .buttonStyle(.plain)
        } else {
            rowContent(entry, isLink: false)
        }
    }

    private func rowContent(_ entry: PlayerGameLog.Entry, isLink: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Spacing.sm) {
                Text(when(entry))
                    .font(.rowMeta)
                    .foregroundStyle(.textSecondary)
                    .frame(width: Self.whenWidth, alignment: .leading)
                Text(entry.isAway ? "@" : "vs")
                    .font(.rowMeta)
                    .foregroundStyle(.textSecondary)
                LogoImage(url: entry.opponentLogoURL)
                    .frame(width: 18, height: 18)
                Text(entry.opponentAbbreviation ?? entry.opponentName ?? "")
                    .font(.rowName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                if let result = resultText(entry) {
                    Text(result)
                        .font(.rowNameEmphasis.monospacedDigit())
                        .foregroundStyle(.textPrimary)
                }
                if isLink {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                }
            }
            Text(log.headline(for: entry, category: category))
                .font(.rowMeta.monospacedDigit())
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .padding(.leading, Self.whenWidth + Spacing.sm)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel(entry))
    }

    /// "Wk 15" in football, "Dec 14" elsewhere.
    private func when(_ entry: PlayerGameLog.Entry) -> String {
        if let week = entry.week, league == .nfl || league == .collegeFootball {
            return "Wk \(week)"
        }
        return entry.date?.formatted(.dateTime.month(.abbreviated).day()) ?? ""
    }

    /// "W 33-30", the player's side first.
    private func resultText(_ entry: PlayerGameLog.Entry) -> String? {
        guard let result = entry.result else { return nil }
        guard let us = entry.teamScore, let them = entry.opponentScore else { return result }
        return "\(result) \(us)-\(them)"
    }

    private func spokenLabel(_ entry: PlayerGameLog.Entry) -> String {
        var parts: [String] = []
        if let date = entry.date {
            parts.append(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        }
        let opponent = entry.opponentName ?? entry.opponentAbbreviation ?? "opponent"
        parts.append(entry.isAway ? "at \(opponent)" : "versus \(opponent)")
        switch entry.result {
        case "W": parts.append("won")
        case "L": parts.append("lost")
        case "T": parts.append("tied")
        default: break
        }
        if let us = entry.teamScore, let them = entry.opponentScore {
            parts.append("\(us) to \(them)")
        }
        parts.append(log.headline(for: entry, category: category))
        return parts.joined(separator: ", ")
    }

    /// A pushable game built from the log's own facts. The game page fetches
    /// its summary by event id, so the header only has to be right until
    /// that lands — and it is, since the log carries both sides and the
    /// score. Teams resolve through the directory where they can, so the
    /// header's team links push the same `Team` every other door does.
    private func game(for entry: PlayerGameLog.Entry) -> Game? {
        guard let teamId = entry.teamId, let opponentId = entry.opponentId else { return nil }
        let us = resolve(id: teamId, name: entry.teamAbbreviation, abbreviation: entry.teamAbbreviation,
                         logo: entry.teamLogoURL)
        let them = resolve(id: opponentId, name: entry.opponentName,
                           abbreviation: entry.opponentAbbreviation, logo: entry.opponentLogoURL)
        let won = entry.result.map { $0 == "W" }
        let lost = entry.result.map { $0 == "L" }
        let ours = Competitor(team: us, score: entry.teamScore.flatMap(Int.init), record: nil,
                              rank: nil, isHome: !entry.isAway, winner: won)
        let theirs = Competitor(team: them, score: entry.opponentScore.flatMap(Int.init), record: nil,
                                rank: nil, isHome: entry.isAway, winner: lost)
        let (home, away) = entry.isAway ? (theirs, ours) : (ours, theirs)
        return Game(id: entry.eventId, date: entry.date, name: nil,
                    shortName: "\(away.team.abbreviation ?? away.team.location) @ \(home.team.abbreviation ?? home.team.location)",
                    weekNumber: entry.week,
                    status: entry.result == nil ? .pre(detail: nil) : .final(detail: nil),
                    home: home, away: away, broadcast: nil)
    }

    private func resolve(id: String, name: String?, abbreviation: String?, logo: URL?) -> Team {
        if let team = directory.team(matching: TeamRef(id: id, league: league)) { return team }
        return Team(id: id, location: name ?? abbreviation ?? "", name: nil,
                    abbreviation: abbreviation, displayName: name, shortDisplayName: nil,
                    logoURL: logo, conferenceId: nil, league: league)
    }
}
