import SwiftUI

/// The Trades tab, on a pro team's page and on a pro league's (the brief's
/// D5): the wire as day cards, newest first, filtered to signings and
/// trades unless the reader asks for everything.
///
/// A trade is two rows, one per side, each in ESPN's own words (D3) —
/// pairing them would mean parsing prose, and a three-team deal is then
/// just three rows. Every state is the entity pages' own: a bare spinner
/// first, a carded `StatusMessage` for failure and emptiness, and the
/// narrowed-empty state's way back out.
struct TradesPane: View {
    /// Nil until the host has made one for this page's team or league.
    let feed: RosterMovesFeed?
    let filter: RosterMove.Filter
    /// Off on a team page — see `RosterMoveRow.showsTeamLogo`.
    var showsTeamLogos = true
    let onShowAll: () -> Void

    private var shown: [RosterMove] {
        (feed?.moves ?? []).filter { filter.shows($0) }
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if let feed, !shown.isEmpty {
                ForEach(RosterMoveDays.days(from: shown)) { card($0) }
                footer(feed)
            } else if let feed, feed.failed {
                StatusMessage(text: "Couldn't load trades.",
                              retry: { Task { await feed.retry() } })
                    .cardSurface()
            } else if let feed, feed.hasLoaded, !feed.isLoading {
                emptyState(feed)
            } else {
                // A lone spinner gets no card — a surface around it hugs
                // into a floating pill (Andy, 2026-08-31).
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xl)
            }
        }
        // No top padding: the pinned header carries it, so the gap is the
        // same whether the header is riding along or stuck.
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    /// One day's moves under the Games tab's Date-card header.
    private func card(_ day: RosterMoveDays.Day) -> some View {
        VStack(spacing: 0) {
            CardHeader(title: day.title)
            VStack(spacing: 0) {
                ForEach(Array(day.moves.enumerated()), id: \.element.id) { index, move in
                    RosterMoveRow(move: move, showsTeamLogo: showsTeamLogos)
                    if index < day.moves.count - 1 {
                        Divider()
                            .overlay(Color.divider)
                            .padding(.leading, Spacing.lg)
                    }
                }
            }
            .padding(.top, Spacing.xs)
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    /// How far back the list reaches, and the way further. A button rather
    /// than loading on scroll: the entity pages lay their panes out eagerly,
    /// so a "load when this appears" row would appear at once and walk the
    /// NFL's seventeen pages in one go.
    @ViewBuilder
    private func footer(_ feed: RosterMovesFeed) -> some View {
        if feed.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
        } else if feed.moreFailed {
            StatusMessage(text: "Couldn't load older moves.",
                          retry: { Task { await feed.retry() } })
                .cardSurface()
        } else if feed.canLoadMore {
            StatusMessage(text: sinceLine(feed), actionTitle: "Show older",
                          retry: { Task { await feed.loadMore() } })
                .cardSurface()
        }
    }

    /// "Since Monday, September 8" — the oldest card's own title, so the
    /// footer and the card above it agree.
    private func sinceLine(_ feed: RosterMovesFeed) -> String {
        guard let oldest = feed.oldestDay else { return "Older moves" }
        let title = RosterMoveDays.title(for: oldest)
        let named = title == "Today" || title == "Yesterday"
        return "Since \(named ? title.lowercased() : title)"
    }

    /// Nothing to show. When the filter is what emptied the pane, say so and
    /// offer everything back — Scores' narrowed-empty rule (2026-08-29), so
    /// a quiet week never reads as a broken tab.
    @ViewBuilder
    private func emptyState(_ feed: RosterMovesFeed) -> some View {
        if filter == .signingsAndTrades, !feed.moves.isEmpty {
            StatusMessage(text: "No signings or trades lately",
                          actionTitle: "Show all moves", retry: onShowAll)
                .cardSurface()
        } else if feed.canLoadMore {
            StatusMessage(text: "No moves this year", actionTitle: "Show older",
                          retry: { Task { await feed.loadMore() } })
                .cardSurface()
        } else {
            StatusMessage(text: "No moves yet")
                .cardSurface()
        }
    }
}
