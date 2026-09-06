import SwiftUI

/// The Games tab's season slate: one card per week in season order, the
/// postseason last. Rows are the Scores `GameRow` — same matchup language,
/// same tap-through to game detail (every stack that can push this page
/// registers a `Game` destination).
struct ConferenceGamesList: View {
    let games: [Game]
    /// What the cards are headed by. Weeks is the season's own clock and
    /// stays the default; the Top 25's toggles can ask for days instead,
    /// or for one unheaded card (Andy, 2026-09-05).
    var grouping: ConferenceSlate.Grouping = .week

    var body: some View {
        ForEach(ConferenceSlate.groups(from: games, by: grouping)) { group in
            VStack(spacing: 0) {
                // An unheaded card is the ungrouped list's whole point —
                // nothing is being grouped, so nothing labels it.
                if !group.title.isEmpty {
                    CardHeader(title: group.title)
                }
                VStack(spacing: 0) {
                    ForEach(Array(group.games.enumerated()), id: \.element.id) { index, game in
                        NavigationLink(value: game) {
                            GameRow(game: game)
                        }
                        .buttonStyle(.plain)
                        if index < group.games.count - 1 {
                            Divider()
                                .overlay(Color.divider)
                                .padding(.leading, Spacing.lg)
                        }
                    }
                }
                .padding(.top, group.title.isEmpty ? 0 : Spacing.xs)
            }
            .padding(.bottom, Spacing.xs)
            .cardSurface()
            .id(group.id)
        }
    }
}

/// Grouping for a season's conference slate. Pure and internal so the
/// week/postseason split is unit-testable without a view in sight.
nonisolated enum ConferenceSlate {
    struct WeekGroup: Identifiable, Equatable {
        let id: String
        let title: String
        let games: [Game]
    }

    /// Regular-season weeks ascending, then a dateless bucket, then the
    /// postseason — whose week numbers restart at 1 and must never land a
    /// title game in "Week 1". Games sort chronologically within a group.
    static func groups(from games: [Game]) -> [WeekGroup] {
        let sorted = games.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        var regular: [Int: [Game]] = [:]
        var postseason: [Game] = []
        var undated: [Game] = []
        for game in sorted {
            if game.seasonType == 3 {
                postseason.append(game)
            } else if let week = game.weekNumber {
                regular[week, default: []].append(game)
            } else {
                undated.append(game)
            }
        }
        var result = regular.keys.sorted().map { week in
            WeekGroup(id: "week-\(week)", title: "Week \(week)", games: regular[week] ?? [])
        }
        if !undated.isEmpty {
            result.append(WeekGroup(id: "week-other", title: "More games", games: undated))
        }
        if !postseason.isEmpty {
            result.append(WeekGroup(id: "week-postseason", title: "Postseason", games: postseason))
        }
        return result
    }

    /// The slate narrowed to one team's games, home or away. A nil id is
    /// the whole slate — "All teams" is the absence of a filter, not a
    /// value the caller has to special-case.
    static func games(_ games: [Game], forTeamId id: String?) -> [Game] {
        guard let id else { return games }
        return games.filter { $0.home.team.id == id || $0.away.team.id == id }
    }
}
