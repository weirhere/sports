import Foundation
import Observation

/// Pending navigation intents from outside the view hierarchy — widget
/// taps and notification taps. Screens consume their pending id once the
/// matching data is loaded; an id that never resolves quietly expires when
/// the next intent replaces it.
@Observable
final class Router {
    var pendingGameId: String?
    var pendingTeamId: String?

    func open(_ link: DeepLink) {
        switch link {
        case .game(let id): pendingGameId = id
        case .team(let id): pendingTeamId = id
        case .teams: break // Landing on the Teams tab is the whole intent.
        }
    }
}
