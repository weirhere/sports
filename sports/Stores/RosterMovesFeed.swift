import Foundation
import Observation

/// One Trades tab's moves, newest first, a page at a time.
///
/// Scoped to a league's whole wire or to one team — the league page and the
/// team page are the same feed with and without `team`. Fetched when the tab
/// first opens and never polled: a roster move isn't live data, and ESPN
/// caches the endpoint for ten seconds anyway.
///
/// **This year, then last year, then stop.** ESPN pages the wire by
/// calendar year, not by season, so "the season so far" isn't a request it
/// can answer. In January the current year is a week old and nearly empty,
/// so once it runs out the feed carries on into the previous one — about a
/// year of moves at any point in the calendar, which covers a whole season
/// in all three leagues. Two years is the ceiling; the tab is a wire, not
/// an archive.
@Observable
@MainActor
final class RosterMovesFeed {
    let league: League
    /// Nil for the league's whole wire.
    let team: Team?

    private(set) var moves: [RosterMove] = []
    /// True once the first page has answered, whatever it said.
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    /// The first page failed: the pane shows Retry instead of rows.
    private(set) var failed = false
    /// A later page failed: the rows stay, and the footer offers Retry.
    private(set) var moreFailed = false

    /// Where the next request goes. Nil once both years are spent.
    private var next: (year: Int?, page: Int)? = (nil, 1)
    /// The calendar year the current requests are reading, once known.
    private var yearOnScreen: Int
    private var seen: Set<String> = []

    @ObservationIgnored private let client = RosterMovesClient()

    init(league: League, team: Team?, now: Date = .now, calendar: Calendar = .current) {
        self.league = league
        self.team = team
        self.yearOnScreen = calendar.component(.year, from: now)
    }

    /// Whether there are older moves to ask for.
    var canLoadMore: Bool { hasLoaded && !failed && next != nil }

    /// The earliest day on screen — the footer says how far back the list
    /// reaches before offering more.
    var oldestDay: Date? { moves.last(where: { $0.day != nil })?.day }

    func loadFirst() async {
        guard !hasLoaded, !isLoading else { return }
        await load()
        // New Year's week: this year's wire is empty, so the tab opens on
        // last year's rather than on "no moves" with older ones a tap away.
        if moves.isEmpty, canLoadMore { await load() }
    }

    func loadMore() async {
        guard canLoadMore, !isLoading else { return }
        await load()
    }

    func retry() async {
        if failed {
            failed = false
            hasLoaded = false
        }
        moreFailed = false
        await load()
    }

    private func load() async {
        guard let request = next else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await client.page(league: league, team: team,
                                             year: request.year, page: request.page)
            let fresh = page.moves.filter { seen.insert($0.id).inserted }
            moves.append(contentsOf: fresh)
            hasLoaded = true
            failed = false
            moreFailed = false
            advance(after: request, pageCount: page.pageCount)
        } catch {
            if hasLoaded { moreFailed = true } else { failed = true }
        }
    }

    /// The next page of this year, or page one of last year once this one
    /// is spent — and nothing after that.
    private func advance(after request: (year: Int?, page: Int), pageCount: Int) {
        if request.page < pageCount {
            next = (request.year, request.page + 1)
        } else if request.year == nil {
            yearOnScreen -= 1
            next = (yearOnScreen, 1)
        } else {
            next = nil
        }
    }
}
