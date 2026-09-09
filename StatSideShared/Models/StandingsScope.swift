import Foundation

/// How wide a standings page tables its teams (Andy, 2026-09-06 — "filter
/// on the standings page to sort through by the whole league … but also by
/// conference … as well as by division").
///
/// A scope is a *view* of one fetch, not a different set of teams: the NFL
/// page shows the same 32 either way, in one table, two, or eight. Which
/// scopes a page offers comes from where that page sits in the league's own
/// hierarchy, so nothing has to be listed per conference — and college
/// football, which nests nothing, offers none at all.
nonisolated enum StandingsScope: String, CaseIterable, Sendable, Identifiable {
    /// Every team in the league, one table — the NFL's 32.
    case league
    /// One table per conference: the AFC and the NFC.
    case conference
    /// One table per division: AFC East through NFC West.
    case division

    var id: String { rawValue }

    /// The chip's label, and the menu row's.
    var title: String {
        switch self {
        case .league: "League"
        case .conference: "Conference"
        case .division: "Division"
        }
    }

    /// The scopes a conference page can show: its own level and everything
    /// under it. The league page offers all three, a conference page the
    /// two below it, and anything that nests nothing — a division, every
    /// college-football conference — offers none, which is what hides the
    /// control.
    static func scopes(for conference: ConferenceID) -> [StandingsScope] {
        // A rung only counts where there is a table at it. College
        // football's division roots sit at the `.league` rung — FBS leads
        // its eleven conferences the way the NFL leads its two — but the
        // sport keeps no 136-team table and nests no divisions under a
        // conference, so a root there offers no choice at all.
        guard Conference.leagueWideId(in: conference.league) != nil else { return [] }
        switch Conference.tier(for: conference.id, in: conference.league) {
        case .league: return [.league, .conference, .division]
        case .conference: return [.conference, .division]
        default: return []
        }
    }

    /// The scopes a *team* page can show: every level the team itself
    /// belongs to — its division, its conference, and the league it plays
    /// in. Where a conference page scopes downward into what it contains,
    /// a team page scopes outward into what contains it, and each step is
    /// still one table with the team's own row in it.
    ///
    /// One level is no choice at all, so college football — whose teams
    /// belong to a conference and nothing else — offers none, exactly as
    /// its conference pages do.
    static func scopes(forTeamIn conference: ConferenceID) -> [StandingsScope] {
        let levels = Set(Conference.chain(for: conference).compactMap {
            scope(at: Conference.tier(for: $0.id, in: $0.league))
        })
        guard levels.count > 1 else { return [] }
        // Widest first, the league page's order.
        return allCases.filter { levels.contains($0) }
    }

    /// Where a team page opens: its conference's table, which is what the
    /// tab has always shown. The league is one step out from there and the
    /// division one step in — a team sits in the middle of its own
    /// hierarchy, so its page has no widest-view-of-itself to default to.
    static func `default`(forTeamIn conference: ConferenceID) -> StandingsScope {
        scopes(forTeamIn: conference).contains(.conference) ? .conference : .division
    }

    /// Whether this scope tables fewer teams than `baseline` — the chip's
    /// ink rule. A page's own default is the baseline, so scoping *out*
    /// (a team page reading the whole league) sits as quiet as the default
    /// does, and only a narrowed table wears the fill.
    func isNarrower(than baseline: StandingsScope) -> Bool {
        rank > baseline.rank
    }

    /// Widest to narrowest, which is `allCases`' own order.
    private var rank: Int {
        StandingsScope.allCases.firstIndex(of: self) ?? 0
    }

    /// The scope a level of the hierarchy is seen at.
    private static func scope(at tier: Conference.Tier) -> StandingsScope? {
        switch tier {
        case .league: .league
        case .conference: .conference
        case .division: .division
        default: nil
        }
    }

    /// Where a page opens. The widest view of itself: the league's own
    /// table on the league page, its 16 on a conference page — and a
    /// division page, which has no scopes to offer, still has to ask for
    /// the divisional tables or it would find nothing at all.
    static func `default`(for conference: ConferenceID) -> StandingsScope {
        switch Conference.tier(for: conference.id, in: conference.league) {
        // A league with no table of its own — college football, whose
        // division roots sit at this rung — opens on the conferences
        // under it instead, which is the widest view it actually has.
        case .league:
            Conference.leagueWideId(in: conference.league) == nil
                ? StandingsScope.conference : StandingsScope.league
        case .division: .division
        default: .conference
        }
    }
}
