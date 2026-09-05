import Foundation
import Observation

/// Pending navigation intents from outside the view hierarchy — widget
/// taps, notification taps, and app-wide search results. Screens consume
/// their pending id once the matching data is loaded; an id that never
/// resolves quietly expires when the next intent replaces it.
@Observable
final class Router {
    var pendingGameId: String?
    var pendingTeamId: String?
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
        case .team(let id): pendingTeamId = id
        case .teams: break // Landing on the Teams tab is the whole intent.
        }
    }
}
