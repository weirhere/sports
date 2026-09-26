import Foundation

/// A table's name with its league joined on — "SEC - NCAAF", "AFC - NFL" —
/// the form the Scores section headers took on 2026-09-25 (#198), for the
/// Leagues tab's Following cards too (Andy, 2026-09-25). A conference names
/// itself, not its sport, so wherever tables from several leagues share a
/// list the name alone is ambiguous: "Eastern" is two different tables.
enum LeagueTitle {
    /// The league a title needs spelled out: nil when the title already
    /// says it — the NFL's own table is titled "NFL". Same rule as the
    /// Scores header's `tagLeague`.
    static func league(_ league: League?, tagging title: String) -> League? {
        guard let league, title != league.shortName, title != league.displayName
        else { return nil }
        return league
    }

    /// "SEC - NCAAF", or the bare title when it already names its league.
    static func joined(_ title: String, league: League?) -> String {
        guard let league = self.league(league, tagging: title) else { return title }
        return "\(title) - \(league.shortName)"
    }

    /// The spoken form: the league spelled out, as the Scores header's
    /// VoiceOver label does ("SEC, college football").
    static func spoken(_ title: String, league: League?) -> String {
        guard let league = self.league(league, tagging: title) else { return title }
        return "\(title), \(league.displayName)"
    }
}
