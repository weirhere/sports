import SwiftUI

/// The game page's standings slice: just the two competing teams — each
/// with its conference, place, and records so far. Same conference means
/// one caption and both rows in place order; a cross-conference matchup
/// gets a caption per side. Rows push the full conference table with the
/// team's row anchored.
struct MatchupStandings: View {
    let away: Team
    let home: Team
    let standings: [ConferenceStandings]

    /// A team's conference, place, and line — nil when no table knows it.
    private func slot(for team: Team) -> (conference: ConferenceStandings,
                                          position: Int,
                                          standing: ConferenceStanding)? {
        for conference in standings {
            if let index = conference.entries.firstIndex(where: { $0.team.id == team.id }) {
                return (conference, index + 1, conference.entries[index])
            }
        }
        return nil
    }

    /// Whether either side has a row worth showing. Preseason hides the
    /// card entirely — the place numbers are last season's carried-over
    /// order (the leader-teaser and cut-line rule) — but "preseason" is a
    /// property of the SEASON, not the matchup: once anyone anywhere has
    /// played, the tables are live and a pre-game page shows both sides'
    /// standings even when the two teams themselves still sit 0-0. The
    /// underway check reads the OVERALL record: a September team
    /// legitimately sits 0-0 in conference while its overall line already
    /// says something.
    static func hasContent(away: Team, home: Team,
                           standings: [ConferenceStandings]) -> Bool {
        let knowsASide = standings.contains { conference in
            conference.entries.contains { $0.team.id == away.id || $0.team.id == home.id }
        }
        let seasonUnderway = standings.contains { conference in
            conference.entries.contains { entry in
                entry.overallRecord != nil && entry.overallRecord != "0-0"
            }
        }
        return knowsASide && seasonUnderway
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The two record columns need their names (Andy, 2026-08-25);
            // hidden at accessibility sizes, where rows stack their
            // records onto a labeled line.
            if !dynamicTypeSize.isAccessibilitySize {
                StandingsColumnCaptions()
            }
            let awaySlot = slot(for: away)
            let homeSlot = slot(for: home)
            if let awaySlot, let homeSlot, awaySlot.conference.id == homeSlot.conference.id {
                caption(awaySlot.conference.name)
                let ordered = [awaySlot, homeSlot].sorted { $0.position < $1.position }
                ForEach(ordered, id: \.standing.id) { entry in
                    row(entry)
                }
            } else {
                if let awaySlot {
                    caption(awaySlot.conference.name)
                    row(awaySlot)
                }
                if let homeSlot {
                    caption(homeSlot.conference.name)
                    row(homeSlot)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func caption(_ name: String) -> some View {
        Text(name)
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func row(_ entry: (conference: ConferenceStandings,
                               position: Int,
                               standing: ConferenceStanding)) -> some View {
        if let conference = entry.conference.conference {
            NavigationLink(value: ConferenceDestination(
                conference: conference,
                name: entry.conference.name,
                highlightTeamId: entry.standing.team.id
            )) {
                ConferenceStandingRow(standing: entry.standing, position: entry.position)
            }
            .buttonStyle(.plain)
        } else {
            ConferenceStandingRow(standing: entry.standing, position: entry.position)
        }
    }
}
