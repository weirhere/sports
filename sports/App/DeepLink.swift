import Foundation

/// The `statside://` grammar. The scheme is deliberately unregistered
/// (no CFBundleURLTypes): widget taps and notification taps deliver to
/// `onOpenURL` without registration, and external openers aren't a v1 need.
nonisolated enum DeepLink: Equatable {
    case game(String)
    case team(String)
    case teams

    init?(url: URL) {
        guard url.scheme == "statside" else { return nil }
        let id = url.pathComponents.count > 1 ? url.pathComponents[1] : nil
        switch url.host() {
        case "game":
            guard let id else { return nil }
            self = .game(id)
        case "team":
            guard let id else { return nil }
            self = .team(id)
        case "teams":
            self = .teams
        default:
            return nil
        }
    }
}
