import Foundation
import Observation

/// One `ScoreboardStore` per league, plus which one the Scores screen is
/// looking at.
///
/// Two stores rather than one keyed store, because almost everything a
/// scoreboard holds is league-shaped: the week strip is (a college Saturday
/// pins back on Sunday, the NFL's week runs Thursday to Monday), the season
/// is, the section pipeline is, and the two leagues' weeks don't line up at
/// all — college football's "Bowls" is a single slot from mid-December to
/// late January, with four NFL playoff rounds inside it.
///
/// What is *not* league-shaped is Following. "My games" shouldn't care which
/// sport they belong to, so the Scores screen asks the unselected leagues
/// for their followed games too (`followedGamesElsewhere`).
@Observable
@MainActor
final class LeagueScoreboards {
    private let stores: [League: ScoreboardStore]

    /// The league on screen. Setting it is the user's explicit choice and
    /// is never overridden by the auto-pick afterwards.
    private(set) var selectedLeague: League

    /// True once the user (or a restored preference) has settled the
    /// league for this launch — the auto-pick only ever fires before this.
    @ObservationIgnored private var selectionIsExplicit = false

    init(selected: League = .collegeFootball,
         stores: [League: ScoreboardStore]? = nil) {
        self.selectedLeague = selected
        self.stores = stores ?? Dictionary(
            uniqueKeysWithValues: League.allCases.map { ($0, ScoreboardStore(league: $0)) }
        )
    }

    func store(for league: League) -> ScoreboardStore {
        // Every league has a store by construction; the fallback exists so
        // a lookup can't crash a screen.
        stores[league] ?? stores[.collegeFootball] ?? ScoreboardStore(league: league)
    }

    /// The store the Scores screen's week strip, sections and filters read.
    var selected: ScoreboardStore { store(for: selectedLeague) }

    var all: [ScoreboardStore] { League.allCases.map(store(for:)) }

    func select(_ league: League) {
        selectionIsExplicit = true
        guard league != selectedLeague else { return }
        selectedLeague = league
    }

    /// Restores the saved preference at launch. Unlike `select`, this does
    /// not count as an explicit choice — the auto-pick is still allowed to
    /// override a *saved* league when exactly one is live, which is the
    /// whole point of it.
    func restore(_ league: League) {
        guard !selectionIsExplicit else { return }
        selectedLeague = league
    }

    // MARK: - Loading and polling

    /// Loads every league's current week at once. Both are needed from the
    /// start: the unselected one feeds the cross-league Following section,
    /// and the auto-pick can't know where the live games are until it has
    /// asked both.
    func loadInitial() async {
        await withTaskGroup(of: Void.self) { group in
            for store in all {
                group.addTask { await store.loadInitial() }
            }
        }
    }

    /// Opens on whichever league is actually playing.
    ///
    /// Deliberately narrow, because an app that rearranges itself is a
    /// surprise: it runs once per cold launch, never on scene-active, only
    /// when *exactly one* league has games in progress, and never over an
    /// explicit choice already made this session. Anything ambiguous — both
    /// live, neither live — leaves the saved preference alone.
    ///
    /// The pick is written back so it also becomes the saved preference:
    /// landing on the NFL on a Sunday and then closing the app should not
    /// spring back to college football on Monday.
    @discardableResult
    func autoSelectLiveLeague() -> League? {
        guard !selectionIsExplicit else { return nil }
        let live = League.allCases.filter { store(for: $0).hasLiveGames }
        guard live.count == 1, let league = live.first else { return nil }
        selectionIsExplicit = true
        selectedLeague = league
        return league
    }

    /// Polls every league that has something live, not just the selected
    /// one: a followed NFL game in the Following section has to keep
    /// ticking while you read the college slate. Each store starts its own
    /// loop only when it needs one, so a quiet league costs nothing.
    func startPollingIfNeeded() {
        for store in all { store.startPollingIfNeeded() }
    }

    func stopPolling() {
        for store in all { store.stopPolling() }
    }

    // MARK: - Cross-league Following

    /// Followed games from every league except `league`, for the Scores
    /// screen's Following section.
    ///
    /// Only while the selected week is the current one. Browsing to college
    /// football's Week 10 is time navigation inside one league; the other
    /// league's games have no business teleporting along with it, and there
    /// is no honest mapping between the two calendars anyway.
    func followedGamesElsewhere(than league: League, following: FollowingStore) -> [Game] {
        guard store(for: league).isOnCurrentWeek else { return [] }
        return League.allCases
            .filter { $0 != league }
            .flatMap { other in store(for: other).games.filter(following.follows) }
    }
}
