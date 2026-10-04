import SwiftUI

/// The Career tab: every season the player has a line for, with the club
/// they played it for, and ESPN's own career totals closing each table.
///
/// Nothing here is summed by the app (E20's Career row, 2026-09-20): the
/// seasons are ESPN's rows and the career line is ESPN's `totals`, so the
/// risks that row set out for a derived career — our numbers disagreeing
/// with theirs, a cost that scales with the career, silent holes — don't
/// arise. One request, the same one the Stats tab already made.
///
/// Seasons or Teams (Andy, 2026-10-03): ESPN's lines newest first, or one
/// line per club, the latest club first. A club's line is the one figure
/// here the app computes — ESPN has no per-club split — and
/// `Category.combined` says column by column how; ESPN's career line still
/// closes the card either way.
struct PlayerCareerPane: View {
    let stats: PlayerStats
    let league: League

    enum Arrangement: Hashable { case seasons, teams }

    @Environment(TeamDirectoryStore.self) private var directory
    @State private var arrangement = Arrangement.seasons

    /// Only a career that passed through more than one club has anything
    /// to regroup.
    private var hasSeveralClubs: Bool {
        Set(stats.categoriesWithLines.flatMap { $0.clubLines }.map(Self.clubKey)).count > 1
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if hasSeveralClubs {
                CapsuleSwitch(options: [(.seasons, "Seasons"), (.teams, "Teams")],
                              selection: $arrangement)
            }
            ForEach(stats.categoriesWithLines) { category in
                let lines = Self.newestFirst(category.clubLines)
                StatTableCard(
                    title: category.title,
                    columns: category.labels,
                    spokenColumns: category.displayNames,
                    rows: arrangement == .teams && hasSeveralClubs
                        ? Self.byClub(lines).map { clubRow($0, in: category) }
                        : lines.map(row),
                    footer: category.career.isEmpty ? nil
                        : StatTableCard.Row(id: "career", title: "Total", values: category.career),
                    leadsWithTeam: true)
            }
        }
    }

    /// This season on top, the way the player is followed now (Andy,
    /// 2026-10-03); ESPN lists them oldest first. Within a year the later
    /// line leads too, so a player traded mid-season shows his new club
    /// first — ESPN's order reversed, with the year as the guarantee.
    static func newestFirst(_ seasons: [PlayerStats.SeasonLine]) -> [PlayerStats.SeasonLine] {
        seasons.enumerated()
            .sorted { ($0.element.year, $0.offset) > ($1.element.year, $1.offset) }
            .map(\.element)
    }

    /// A line's club, for gathering: ESPN's team id, else the payload's own
    /// name for it.
    static func clubKey(_ line: PlayerStats.SeasonLine) -> String {
        line.teamId ?? line.teamName ?? ""
    }

    /// Newest-first lines gathered by club, in the order each club first
    /// appears — so the current club leads, and each club's seasons stay
    /// newest first. A player who went back to an old club has one block
    /// for it, at its latest stint.
    static func byClub(_ lines: [PlayerStats.SeasonLine]) -> [[PlayerStats.SeasonLine]] {
        var order: [String] = []
        var blocks: [String: [PlayerStats.SeasonLine]] = [:]
        for line in lines {
            let key = clubKey(line)
            if blocks[key] == nil { order.append(key) }
            blocks[key, default: []].append(line)
        }
        return order.compactMap { blocks[$0] }
    }

    /// A club's seasons as one row: its logo and name over the span it
    /// played there, the numbers `combined` across those seasons.
    private func clubRow(_ lines: [PlayerStats.SeasonLine],
                         in category: PlayerStats.Category) -> StatTableCard.Row {
        guard let newest = lines.first, let oldest = lines.last else {
            return StatTableCard.Row(id: "club", title: "", values: [])
        }
        let club = row(newest)
        let span = lines.count == 1 ? newest.label : "\(oldest.label)–\(newest.label)"
        return StatTableCard.Row(id: "club-\(Self.clubKey(newest))",
                                 title: club.subtitle == nil ? "Other" : club.title,
                                 subtitle: span,
                                 values: category.combined(lines),
                                 logoURL: club.logoURL,
                                 team: club.team)
    }

    /// The club's logo and name over the season, FotMob's career row
    /// (Andy, 2026-10-03). The name is the short one ("Georgia", "Chiefs")
    /// so the stats still fit beside it. A club the directory can't
    /// resolve (a college player's old school outside the fetched
    /// divisions) keeps the payload's own name and an empty logo disc; a
    /// line with no club at all is titled by its season alone.
    private func row(_ line: PlayerStats.SeasonLine) -> StatTableCard.Row {
        let team = line.teamId.flatMap { directory.team(matching: TeamRef(id: $0, league: league)) }
        guard let name = team.map({ $0.shortDisplayName ?? $0.location }) ?? line.teamName,
              !name.isEmpty else {
            return StatTableCard.Row(id: line.id, title: line.label, values: line.values)
        }
        return StatTableCard.Row(id: line.id, title: name, subtitle: line.label,
                                 values: line.values, logoURL: team?.logoURL, team: team)
    }
}
