import Foundation

/// The `statside://` grammar. The scheme is deliberately unregistered
/// (no `CFBundleURLTypes`): widgetURL and notification taps deliver to
/// `onOpenURL` without registration, and registering would force a partial
/// Info.plist for external openers nobody needs yet.
nonisolated enum DeepLink: Equatable {
    case game(String)
    /// A team, and the league whose id space its id belongs to. The league
    /// is nil for the bare `statside://team/{id}` form, which cannot be
    /// disambiguated — ids collide across leagues (5 is UAB and the
    /// Browns). Prefer `statside://team/{league}/{id}`.
    case team(String, League?)
    case teams

    init?(url: URL) {
        guard url.scheme == "statside" else { return nil }
        let path = url.pathComponents.dropFirst()
        switch url.host() {
        case "game":
            guard let id = path.first else { return nil }
            self = .game(id)
        case "team":
            // `team/nfl/5` qualifies; `team/5` is the legacy bare form.
            if path.count > 1, let league = League(rawValue: path.first ?? "") {
                guard let id = path.dropFirst().first else { return nil }
                self = .team(id, league)
            } else {
                guard let id = path.first else { return nil }
                self = .team(id, nil)
            }
        case "teams":
            self = .teams
        default:
            return nil
        }
    }
}
