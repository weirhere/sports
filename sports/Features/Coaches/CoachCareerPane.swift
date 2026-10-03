import SwiftUI

/// The Career tab: every job as a row (team, years, record), then the
/// season-by-season table. "Where they coached before" is the first card;
/// the second is the numbers behind it.
struct CoachCareerPane: View {
    let profile: CoachProfile
    let teams: [String: CoachClient.TeamLabel]
    let league: League

    @Environment(TeamDirectoryStore.self) private var directory

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if profile.seasons.isEmpty {
                StatusMessage(text: "No head coaching seasons on record in the \(league.shortName).")
                    .cardSurface()
            } else {
                stintsCard
                seasonsTable
            }
        }
    }

    private var stintsCard: some View {
        let stints = profile.stints
        return VStack(spacing: 0) {
            CardHeader(title: "Teams coached")
            ForEach(Array(stints.enumerated()), id: \.element.id) { index, stint in
                stintRow(stint)
                if index < stints.count - 1 {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                }
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    /// A link to the team's page when the directory knows the team, which
    /// it always does for the pro leagues; a plain row when it doesn't.
    @ViewBuilder
    private func stintRow(_ stint: CoachStint) -> some View {
        if let team = directory.team(matching: TeamRef(id: stint.teamId, league: league)) {
            NavigationLink(value: team) {
                CoachStintRow(stint: stint, label: label(stint.teamId, team: team),
                              league: league, isLink: true)
            }
            .buttonStyle(.plain)
        } else {
            CoachStintRow(stint: stint, label: label(stint.teamId, team: nil),
                          league: league, isLink: false)
        }
    }

    private func label(_ teamId: String, team: Team?) -> CoachClient.TeamLabel {
        teams[teamId]
            ?? team.map { .init(name: $0.displayName ?? $0.location, abbreviation: $0.abbreviation,
                                logoURL: $0.logoURL) }
            ?? .init(name: "Team \(teamId)", abbreviation: nil, logoURL: nil)
    }

    /// One row per season: W, L, the ties and overtime-loss columns only
    /// when some season has one, and PCT.
    private var seasonsTable: some View {
        let lines = profile.seasons.compactMap(\.record)
        let showsTies = lines.contains { $0.ties > 0 }
        let showsOTL = lines.contains { $0.overtimeLosses > 0 }
        let columns = ["W", "L"] + (showsTies ? ["T"] : []) + (showsOTL ? ["OTL"] : []) + ["PCT"]

        func values(_ record: CoachRecord?) -> [String] {
            guard let record else { return columns.map { _ in "–" } }
            var out = [String(record.wins), String(record.losses)]
            if showsTies { out.append(String(record.ties)) }
            if showsOTL { out.append(String(record.overtimeLosses)) }
            out.append(record.winPercentText ?? "–")
            return out
        }

        let total = profile.records.first { $0.kind == .regular }
            ?? profile.records.first { $0.kind == .total }
        return StatTableCard(
            title: "By season",
            columns: columns,
            spokenColumns: columns.map(spoken),
            // The player Career tab's row (2026-10-03): logo, club, season
            // beneath.
            rows: profile.seasons.map { season in
                let team = teams[season.teamId]
                return StatTableCard.Row(id: season.id, title: team?.name ?? league.seasonLabel(season.year),
                                         subtitle: team == nil ? nil : league.seasonLabel(season.year),
                                         values: values(season.record), logoURL: team?.logoURL)
            },
            footer: total.map { StatTableCard.Row(id: "career", title: "Career", values: values($0)) },
            leadsWithTeam: true)
    }

    private func spoken(_ column: String) -> String {
        switch column {
        case "W": "Wins"
        case "L": "Losses"
        case "T": "Ties"
        case "OTL": "Overtime losses"
        default: "Win percentage"
        }
    }
}
