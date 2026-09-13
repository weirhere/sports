import SwiftUI

/// The H2H tab: what these two have done to each other, and the games that
/// say so.
///
/// Two cards. The tally leads — two logos, two numbers, the leader's in ink
/// and the other muted, which is the centered score line from the header
/// above applied to a series instead of a game. Then the meetings, newest
/// first, as `GameRow`s that push their own detail page: the same matchup
/// language the rest of the app speaks, and a rivalry game from 2019 is one
/// tap from its box score.
///
/// The window caption is not decoration. A series assembled from ten
/// seasons of schedules is not the all-time record and must never be read
/// as one, so "Since 2017" rides in the card header where the number can't
/// be seen without it.
struct HeadToHeadPane: View {
    let away: Team
    let home: Team
    let state: LoadState

    /// What the tab has to show. The distinction that matters is the last
    /// two: an empty series and a failed fetch look identical on screen,
    /// and only one of them gets to say "no meetings".
    enum LoadState {
        case loading
        case failed
        case loaded(HeadToHead)
    }

    /// Retried by the pane's own button — the screen's pull-to-refresh
    /// reloads the summary, which is a different fetch.
    var onRetry: () -> Void

    /// Both crests, and the empty slot the dash sits under. Scaled with the
    /// numbers beside them so the row stays a row at every text size.
    @ScaledMetric(relativeTo: .largeTitle) private var markSize: CGFloat = 36

    var body: some View {
        VStack(spacing: Spacing.sm) {
            switch state {
            case .loading:
                ProgressView()
                    .padding(.vertical, Spacing.xl)
                    .frame(maxWidth: .infinity)
            case .failed:
                retry
            case .loaded(let series):
                tally(series)
                if !series.isEmpty {
                    meetings(series)
                }
            }
        }
        .padding(Spacing.sm)
    }

    // MARK: - The tally

    private func tally(_ series: HeadToHead) -> some View {
        VStack(spacing: 0) {
            CardHeader(title: "Series", subtitle: series.windowLabel)
            if series.isEmpty {
                // Honest about the window rather than claiming a first
                // meeting: these two may well have played in 1994, and the
                // series simply doesn't reach back that far.
                Text("These two haven't met \(series.windowLabel.lowercased()).")
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
                    .padding(.horizontal, Spacing.md)
            } else {
                HStack(alignment: .top, spacing: Spacing.lg) {
                    side(away, wins: series.awayWins, leads: series.leader == .away)
                    VStack(spacing: Spacing.xs) {
                        // The mark's own row, held empty, so the dash lands
                        // level with the two numbers instead of level with
                        // the crests above them.
                        Color.clear.frame(width: 1, height: markSize)
                        Text("–")
                            .font(.scoreHero)
                            .foregroundStyle(.textSecondary)
                        if series.ties > 0 {
                            Text("\(series.ties) \(series.ties == 1 ? "tie" : "ties")")
                                .font(.meta)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    side(home, wins: series.homeWins, leads: series.leader == .home)
                }
                .padding(.vertical, Spacing.lg)
                .padding(.horizontal, Spacing.md)
                // One sentence rather than six fragments, the GameRow rule.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(series.summarySentence(away: away, home: home))
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    /// One team's half of the tally. The muted ink on the trailing side is
    /// the header score line's own rule — the leader reads without color.
    private func side(_ team: Team, wins: Int, leads: Bool) -> some View {
        VStack(spacing: Spacing.xs) {
            LogoImage(url: team.logoURL)
                .frame(width: markSize, height: markSize)
            Text("\(wins)")
                .font(.scoreHero)
                .foregroundStyle(leads ? Color.textPrimary : Color.textSecondary)
            Text(team.location)
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - The meetings

    private func meetings(_ series: HeadToHead) -> some View {
        VStack(spacing: 0) {
            CardHeader(title: "Previous meetings",
                       subtitle: "\(series.meetings.count)")
            VStack(spacing: 0) {
                ForEach(Array(series.meetings.enumerated()), id: \.element.id) { index, game in
                    NavigationLink(value: game) {
                        // Ten rows can be ten different years — see
                        // `GameRow.showsYear`.
                        GameRow(game: game, showsYear: true)
                    }
                    // A full-width surface is wider than the tab swipe that
                    // crosses it, so `.plain` would fire on the way out of
                    // one (2026-09-06).
                    .buttonStyle(SwipeSafeButtonStyle())
                    if index < series.meetings.count - 1 {
                        Divider()
                            .overlay(Color.divider)
                            .padding(.leading, Spacing.lg)
                    }
                }
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    private var retry: some View {
        VStack(spacing: Spacing.sm) {
            Text("Couldn't load the series.")
                .font(.teamName)
                .foregroundStyle(.textSecondary)
            Button("Retry", action: onRetry)
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}
