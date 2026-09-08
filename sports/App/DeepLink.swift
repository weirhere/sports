import Foundation

/// The `statside://` grammar. The scheme is deliberately unregistered
/// (no `CFBundleURLTypes`): widgetURL and notification taps deliver to
/// `onOpenURL` without registration, and registering would force a partial
/// Info.plist for external openers nobody needs yet.
nonisolated enum DeepLink: Equatable {
    /// A game, and the local day it kicks off on where the link knows it —
    /// `statside://game/{id}?day=2026-09-13`.
    ///
    /// The day is a hint, never the identity: the id is what resolves. But
    /// the Scores screen holds five days at a time and the widget lists
    /// games a fortnight out, so an id alone is unresolvable for most of
    /// what a widget row can show (Andy, 2026-09-07). Nil for a link
    /// written before the hint existed, and for a kickoff reminder, whose
    /// game is always inside the loaded window anyway.
    case game(String, day: Date?)
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
            self = .game(id, day: Self.day(in: url))
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

    /// The `?day=2026-09-13` hint, in the app's own day spelling.
    private static func day(in url: URL) -> Date? {
        guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "day" })?.value
        else { return nil }
        return DayFormat.date(fromId: value)
    }
}
