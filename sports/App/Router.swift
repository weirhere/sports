import Foundation
import Observation

/// A team to open, qualified by league.
///
/// ESPN's team ids collide across leagues — 5 is UAB in college football
/// and the Browns in the NFL, 26 is UCLA and the Seahawks — so an intent
/// carrying a bare id resolved to whichever league the directory published
/// first, which is why searching "Browns" opened UAB (Andy, 2026-09-06).
/// The league is what makes it unambiguous, exactly as it does in
/// `FollowKey` and `ConferenceID`.
nonisolated struct TeamRef: Equatable, Sendable {
    let id: String
    /// Nil only for a bare `statside://team/{id}` link, which carries no
    /// league to be qualified by. Resolution falls back to a preference
    /// order rather than guessing — see `TeamDirectoryStore.team(matching:)`.
    var league: League?

    init(id: String, league: League? = nil) {
        self.id = id
        self.league = league
    }

    init(_ team: Team) {
        self.init(id: team.id, league: team.league)
    }
}

/// Pending navigation intents from outside the view hierarchy — widget
/// taps, notification taps, and app-wide search results. Screens consume
/// their pending id once the matching data is loaded; an id that never
/// resolves quietly expires when the next intent replaces it.
@Observable
final class Router {
    var pendingGameId: String?
    var pendingTeam: TeamRef?
    /// Search's conference intent. Today the Teams tab consumes it (expand
    /// + scroll to the section); a dedicated conference destination can take
    /// it over without search changing.
    var pendingConferenceId: ConferenceID?
    /// In-app "go browse teams" intent — the Scores follow prompt's CTA.
    /// RootView switches tabs and resets it; no id to resolve.
    var pendingTeamsBrowse = false

    func open(_ link: DeepLink) {
        switch link {
        case .game(let id): pendingGameId = id
        case .team(let id, let league): pendingTeam = TeamRef(id: id, league: league)
        case .teams: break // Landing on the Teams tab is the whole intent.
        }
    }
}
