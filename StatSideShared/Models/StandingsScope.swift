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
        switch Conference.tier(for: conference.id, in: conference.league) {
        case .league: [.league, .conference, .division]
        case .nflConference: [.conference, .division]
        default: []
        }
    }

    /// Where a page opens. The widest view of itself: the league's own
    /// table on the league page, its 16 on a conference page — and a
    /// division page, which has no scopes to offer, still has to ask for
    /// the divisional tables or it would find nothing at all.
    static func `default`(for conference: ConferenceID) -> StandingsScope {
        switch Conference.tier(for: conference.id, in: conference.league) {
        case .league: .league
        case .nflDivision: .division
        default: .conference
        }
    }
}
