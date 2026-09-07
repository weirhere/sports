import Foundation

/// The writing half of the `statside://` grammar; `DeepLink` in the app
/// target is the reading half.
///
/// It lives in shared code because the widget writes most of these links
/// and can't see the app's parser. The two halves were a hardcoded string
/// in one target and a switch in the other, which is exactly how a link
/// comes to carry less than the reader knows how to ask for — the widget
/// was writing bare `statside://game/{id}` long after the screen needed a
/// day to find the game (Andy, 2026-09-07).
///
/// The scheme stays unregistered: widgetURL and notification taps reach
/// `onOpenURL` without `CFBundleURLTypes`.
nonisolated enum DeepLinkURL {
    /// `statside://game/{id}?day=2026-09-13`.
    ///
    /// The day is a hint, never the identity — the id is what resolves.
    /// It says which day's slate to fetch when the game isn't in the five
    /// the Scores screen holds, which is most of what a widget row shows.
    static func game(id: String, day: Date? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "statside"
        components.host = "game"
        components.path = "/\(id)"
        if let day {
            components.queryItems = [URLQueryItem(name: "day", value: DayFormat.id(for: day))]
        }
        return components.url
    }

    /// `statside://teams` — the widget's "you follow nobody" landing, and
    /// the fallback for a row whose own link couldn't be built.
    ///
    /// Force-unwrapped deliberately: a literal with no runtime input. The
    /// no-force-unwrap rule guards decode paths, where the input is
    /// ESPN's word for something.
    static let teams = URL(string: "statside://teams")!
}
