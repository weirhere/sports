import SwiftUI

/// The Games tab's season slate: one card per week in season order, the
/// postseason last. Rows are the Scores `GameRow` — same matchup language,
/// same tap-through to game detail (every stack that can push this page
/// registers a `Game` destination).
///
/// Mid-season the cards that are already played fold behind one "Earlier
/// games" row, so the pane opens on the card holding the next game with
/// the page still at its true top (Andy, 2026-09-08). The split itself is
/// `ConferenceSlate.fold`, which carries the reasoning.
struct ConferenceGamesList: View {
    let games: [Game]
    /// What the cards are headed by. Weeks is the season's own clock and
    /// stays the default; the Top 25's toggles can ask for days instead,
    /// or for one unheaded card (Andy, 2026-09-05).
    var grouping: ConferenceSlate.Grouping = .week

    /// Whether the season's spent cards are showing. Collapsed on arrival
    /// mid-season, which is the whole point — see `ConferenceSlate.fold`.
    /// Held across a season or filter change on purpose: a user who asked
    /// for the history once shouldn't have to ask again to flip back.
    @State private var showsEarlier = false

    var body: some View {
        let fold = ConferenceSlate.fold(ConferenceSlate.groups(from: games, by: grouping))
        // Same spacing as the panes that host this list, so nesting a
        // stack inside theirs lays out exactly as the loose cards did.
        VStack(spacing: Spacing.sm) {
            if !fold.earlier.isEmpty {
                earlierRow(fold.earlier)
                if showsEarlier {
                    ForEach(fold.earlier) { card($0) }
                }
            }
            ForEach(fold.upcoming) { card($0) }
        }
    }

    /// The fold's one row: what's behind it, and the way in. Expanding
    /// pushes the next game's card down rather than moving it, which is
    /// what keeps the season in order — the history lands above the card
    /// it happened before.
    private func earlierRow(_ groups: [ConferenceSlate.WeekGroup]) -> some View {
        let count = groups.reduce(0) { $0 + $1.games.count }
        return Button {
            withAnimation(.default) { showsEarlier.toggle() }
        } label: {
            HStack(spacing: Spacing.sm) {
                Text("Earlier games")
                    .font(.sectionHeader)
                    .foregroundStyle(.textPrimary)
                Text("\(count)")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.textSecondary)
                    .rotationEffect(.degrees(showsEarlier ? 180 : 0))
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
        }
        // The entity pages swipe between tabs, and a full-width surface is
        // wider than any swipe, so `.plain` would fire on the way out of
        // one (2026-09-06). Named, not `.swipeSafe` — the shorthand is
        // deliberately absent.
        .buttonStyle(SwipeSafeButtonStyle())
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Earlier games, \(count) \(count == 1 ? "game" : "games")")
        .accessibilityValue(showsEarlier ? "expanded" : "collapsed")
        .accessibilityAddTraits(.isButton)
    }

    private func card(_ group: ConferenceSlate.WeekGroup) -> some View {
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

/// Grouping for a season's conference slate. Pure and internal so the
/// week/postseason split is unit-testable without a view in sight.
nonisolated enum ConferenceSlate {
    struct WeekGroup: Identifiable, Equatable {
        let id: String
        let title: String
        let games: [Game]
    }

    /// The preseason first, then regular-season weeks ascending, then a
    /// dateless bucket, then the postseason — whose week numbers restart
    /// at 1 and must never land a title game in "Week 1". Games sort
    /// chronologically within a group.
    ///
    /// The preseason is split off for the same reason the postseason is
    /// (Andy, 2026-09-06): its weeks restart too, so the Hall of Fame Game
    /// and the NFL's opening Thursday were sharing a card headed "Week 1".
    static func groups(from games: [Game]) -> [WeekGroup] {
        let sorted = games.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        var preseason: [Int: [Game]] = [:]
        var preseasonUndated: [Game] = []
        var regular: [Int: [Game]] = [:]
        var postseason: [Game] = []
        var undated: [Game] = []
        for game in sorted {
            switch game.seasonType {
            case 3:
                postseason.append(game)
            case 1:
                if let week = game.weekNumber {
                    preseason[week, default: []].append(game)
                } else {
                    preseasonUndated.append(game)
                }
            default:
                if let week = game.weekNumber {
                    regular[week, default: []].append(game)
                } else {
                    undated.append(game)
                }
            }
        }
        var result = preseason.keys.sorted().map { week -> WeekGroup in
            let weekGames = preseason[week] ?? []
            return WeekGroup(id: "preseason-\(week)",
                             title: preseasonTitle(week: week, league: league(of: weekGames)),
                             games: weekGames)
        }
        if !preseasonUndated.isEmpty {
            result.append(WeekGroup(id: "preseason-other", title: "Preseason",
                                    games: preseasonUndated))
        }
        result += regular.keys.sorted().map { week in
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

    /// What a preseason card is headed by.
    ///
    /// ESPN numbers the preseason from the Hall of Fame Game: that game is
    /// week 1 and the three preseason weekends are 2, 3 and 4, which is why
    /// the label is the week number minus its opener. A league that
    /// numbers its preseason from 1 keeps its own numbers — only the NFL
    /// plays a Hall of Fame Game.
    static func preseasonTitle(week: Int?, league: League) -> String {
        guard let week else { return "Preseason" }
        guard league == .nfl else { return "Preseason Week \(week)" }
        return week <= 1 ? "Hall of Fame Game" : "Preseason Week \(week - 1)"
    }

    /// Whose preseason a card belongs to. Read off the games themselves —
    /// a conference page's slate is one league's by construction.
    private static func league(of games: [Game]) -> League {
        games.first?.home.team.league ?? .collegeFootball
    }

    /// The slate narrowed to one team's games, home or away. A nil id is
    /// the whole slate — "All teams" is the absence of a filter, not a
    /// value the caller has to special-case.
    static func games(_ games: [Game], forTeamId id: String?) -> [Game] {
        guard let id else { return games }
        return games.filter { $0.home.team.id == id || $0.away.team.id == id }
    }
}
