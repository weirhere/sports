import Foundation

/// A numeric column in a standings table, and what a row says about it out
/// loud.
///
/// Per league, because the leagues genuinely disagree about what a standing
/// *is*. Football ranks on records and shows the conference one beside the
/// overall. The NBA ranks on win percentage and answers "how far back are
/// we" with games behind. The NHL ranks on points — and ships no conference
/// record at all (`vsconf` is simply absent from its payload, verified live
/// 2026-09-08), so a CONF column there would be a permanent dash under a
/// caption promising a number.
nonisolated struct StandingsColumn: Hashable, Sendable, Identifiable {
    enum Field: String, Hashable, Sendable {
        case inGroupRecord, overallRecord, winLossOTL
        case gamesPlayed, points, winPercent, gamesBehind
        case wins, losses, ties
        case homeRecord, awayRecord, divisionRecord
        case pointsFor, pointsAgainst, pointDifferential, streak

        /// Whether the value is a record ("2-0") rather than a number.
        /// Only these get the dash-to-"and" treatment when spoken — a
        /// differential of "-12" read that way says "and 12".
        var isRecord: Bool {
            switch self {
            case .inGroupRecord, .overallRecord, .winLossOTL,
                 .homeRecord, .awayRecord, .divisionRecord: true
            default: false
            }
        }
    }

    /// What the row reads off the standing.
    let field: Field
    /// The table's own caption — "CONF", "PTS", "GB".
    let caption: String
    /// What VoiceOver calls it inside the row's sentence.
    let spoken: String
    /// Base width at `.subheadline`, scaled by the row's `@ScaledMetric`.
    let width: CGFloat

    var id: String { field.rawValue }
}

nonisolated extension League {
    /// The columns this league's standings tables carry, left to right.
    var standingsColumns: [StandingsColumn] {
        switch self {
        case .collegeFootball:
            [StandingsColumn(field: .inGroupRecord, caption: "CONF",
                             spoken: "in conference", width: 44),
             StandingsColumn(field: .overallRecord, caption: "OVR",
                             spoken: "overall", width: 44)]
        // The NFL's own table, in ESPN's order (Andy, 2026-09-13). W-L-T
        // replaces the OVR summary rather than sitting beside it: three
        // columns and one string are the same three numbers, and the
        // league that still plays ties is the one that needs them apart.
        // Wider than a phone by design — see `standingsScrollsHorizontally`.
        case .nfl:
            [StandingsColumn(field: .wins, caption: "W",
                             spoken: "wins", width: 22),
             StandingsColumn(field: .losses, caption: "L",
                             spoken: "losses", width: 22),
             StandingsColumn(field: .ties, caption: "T",
                             spoken: "ties", width: 22),
             StandingsColumn(field: .winPercent, caption: "PCT",
                             spoken: "win percentage", width: 42),
             StandingsColumn(field: .homeRecord, caption: "HOME",
                             spoken: "at home", width: 42),
             StandingsColumn(field: .awayRecord, caption: "AWAY",
                             spoken: "away", width: 42),
             StandingsColumn(field: .divisionRecord, caption: "DIV",
                             spoken: "in division", width: 42),
             StandingsColumn(field: .inGroupRecord, caption: "CONF",
                             spoken: "in conference", width: 42),
             StandingsColumn(field: .pointsFor, caption: "PF",
                             spoken: "points for", width: 30),
             StandingsColumn(field: .pointsAgainst, caption: "PA",
                             spoken: "points against", width: 30),
             StandingsColumn(field: .pointDifferential, caption: "DIFF",
                             spoken: "point differential", width: 38),
             StandingsColumn(field: .streak, caption: "STRK",
                             spoken: "streak", width: 34)]
        case .nba:
            [StandingsColumn(field: .overallRecord, caption: "W-L",
                             spoken: "overall", width: 44),
             StandingsColumn(field: .winPercent, caption: "PCT",
                             spoken: "win percentage", width: 38),
             StandingsColumn(field: .gamesBehind, caption: "GB",
                             spoken: "games back", width: 32)]
        case .nhl:
            // Points is the ranking; the record has three numbers because
            // a game lost in overtime is still worth a point.
            [StandingsColumn(field: .gamesPlayed, caption: "GP",
                             spoken: "games played", width: 26),
             StandingsColumn(field: .winLossOTL, caption: "W-L-OTL",
                             spoken: "and overtime losses", width: 62),
             StandingsColumn(field: .points, caption: "PTS",
                             spoken: "points", width: 30)]
        }
    }

    /// Whether this league's table is wider than a phone, so the identity
    /// column pins and the numbers scroll under it (ESPN's and FotMob's
    /// pattern). True for exactly the league whose column set can't fit:
    /// a set that fits must never become a scroller, because a scroller
    /// says "there is more here" and there wouldn't be.
    var standingsScrollsHorizontally: Bool { self == .nfl }

    /// Whether this league's `/summary` carries the standings table the
    /// matchup card wants, so the game page can skip its second request
    /// (E21, 2026-09-21).
    ///
    /// True for exactly college football, and the reason is what the
    /// payload contains rather than what it's called. CFB's summary ships
    /// **both competing conferences in full**, each entry carrying
    /// `total` and `vsconf` — which is the card's whole column set, OVR
    /// and CONF. The NBA's and NHL's ship the **division** (Boston's
    /// Atlantic, Vegas's Pacific), and short of the card's columns at
    /// that: the NBA sends no `total` summary and the NHL no
    /// `gamesplayed`. A division table under a caption the card would
    /// have to invent, missing a column, is worse than the request it
    /// saves — so the winter leagues keep the fetch. The NFL keeps it
    /// too, for the plainer reason that no NFL summary has ever been
    /// captured, and a guess about a payload is what the DTO rule exists
    /// to prevent.
    var summaryCarriesMatchupStandings: Bool { self == .collegeFootball }

    /// The columns the game page's matchup slice shows — two rows about
    /// two teams, not a table.
    ///
    /// Every league's own set, except the one wide enough to scroll: a
    /// twelve-column scroller inside a card about this game would be
    /// answering the league page's question in the wrong place. The pair
    /// it keeps instead is the one every football table kept before
    /// 2026-09-13 — where these two sit in their conference, and what
    /// they are overall.
    var matchupStandingsColumns: [StandingsColumn] {
        guard standingsScrollsHorizontally else { return standingsColumns }
        return [StandingsColumn(field: .inGroupRecord, caption: "CONF",
                                spoken: "in conference", width: 44),
                StandingsColumn(field: .overallRecord, caption: "OVR",
                                spoken: "overall", width: 44)]
    }
}

nonisolated extension ConferenceStanding {
    /// What one column of a table shows for this row, already formatted —
    /// nil where the payload didn't carry the stat, which drops the number
    /// rather than the row.
    func value(for column: StandingsColumn) -> String? {
        switch column.field {
        case .inGroupRecord: conferenceRecord
        case .overallRecord: overallRecord
        case .winLossOTL: winLossOTL
        case .gamesPlayed: gamesPlayed.map(String.init)
        case .points: points.map(String.init)
        // ".732", not "0.732" — every basketball table drops the zero.
        case .winPercent: winPercent.map {
            String(format: "%.3f", $0).replacingOccurrences(of: "0.", with: ".")
        }
        case .gamesBehind: gamesBehind
        case .wins: wins.map(String.init)
        case .losses: losses.map(String.init)
        case .ties: ties.map(String.init)
        case .homeRecord: homeRecord
        case .awayRecord: awayRecord
        case .divisionRecord: divisionRecord
        case .pointsFor: pointsFor.map(String.init)
        case .pointsAgainst: pointsAgainst.map(String.init)
        case .pointDifferential: pointDifferential
        case .streak: streak
        }
    }

    /// The overall record, in whatever shape the league writes one —
    /// "13-2" in football and basketball, "53-22-7" in hockey.
    var displayRecord: String? { overallRecord ?? winLossOTL }

    /// Whether this team has played anything yet. A 0-0 row is last
    /// season's carried-over order, not information, and it is what the
    /// preseason gates on the matchup card and the record card ask about.
    var hasPlayed: Bool {
        if let gamesPlayed { return gamesPlayed > 0 }
        guard let record = displayRecord else { return false }
        return record != "0-0" && record != "0-0-0"
    }

    /// Whether the standing this table is *sorted* by means anything yet.
    ///
    /// In football that's the conference record, which stays 0-0 into
    /// September while the overall one already talks — a card teasing a
    /// "leader" then is showing last season's order. Leagues that keep no
    /// in-group record (the NHL ships no `vsconf` at all) fall back to
    /// whether the team has played, because there is nothing else to ask.
    var hasStartedInGroupPlay: Bool {
        guard let conferenceRecord else { return hasPlayed }
        return conferenceRecord != "0-0"
    }
}
