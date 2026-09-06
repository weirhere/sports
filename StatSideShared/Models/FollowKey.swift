import Foundation

/// The league-qualified spelling of a followed team — `"cfb:130"`,
/// `"nfl:26"`.
///
/// ESPN team ids collide across leagues: 26 is UCLA *and* the Seattle
/// Seahawks, and 20 of the NFL's 32 ids have a college twin. The follow
/// set therefore stores this, never a bare id.
///
/// It lives in shared code because three processes read the same set and
/// had each grown their own `dropFirst`: the app's stores, the widget
/// extension, and the Siri intent. One parser means one answer.
nonisolated struct FollowKey: Hashable, Sendable {
    let league: League
    let teamId: String

    init(league: League, teamId: String) {
        self.league = league
        self.teamId = teamId
    }

    var rawValue: String { "\(league.rawValue):\(teamId)" }

    /// Parses a stored key. A bare id predates the league axis and reads as
    /// college football — the same fallback the namespacing migration used,
    /// kept here so a key that somehow escaped it still resolves.
    init?(_ rawValue: String) {
        // Empty components are kept, not dropped: `split` discards them by
        // default, which made "nfl:" parse as a *college* team named "nfl"
        // and ":26" as college team 26. A malformed key must fail, not
        // resolve to a plausible-looking wrong one.
        let parts = rawValue.split(separator: ":", maxSplits: 1,
                                   omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            guard !parts[0].isEmpty else { return nil }
            self.init(league: .collegeFootball, teamId: String(parts[0]))
        case 2:
            guard let league = League(rawValue: String(parts[0])), !parts[1].isEmpty
            else { return nil }
            self.init(league: league, teamId: String(parts[1]))
        default:
            return nil
        }
    }
}

nonisolated extension Collection where Element == String {
    /// The stored keys that parse, as values.
    var followKeys: [FollowKey] { compactMap(FollowKey.init) }

    /// Followed team ids within one league, unqualified — what a per-league
    /// fetcher (a schedule, a scoreboard) actually wants.
    func followedTeamIds(in league: League) -> Set<String> {
        Set(followKeys.filter { $0.league == league }.map(\.teamId))
    }

    /// The leagues this follow set actually touches.
    ///
    /// Every caller that fans out per league asks this first, so a
    /// college-football-only user never pays for an NFL request — the
    /// polite-guest rule survives the second league.
    var followedLeagues: [League] {
        let touched = Set(followKeys.map(\.league))
        return League.allCases.filter(touched.contains)
    }
}
