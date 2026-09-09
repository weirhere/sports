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
        case .collegeFootball, .nfl:
            [StandingsColumn(field: .inGroupRecord, caption: "CONF",
                             spoken: "in conference", width: 44),
             StandingsColumn(field: .overallRecord, caption: "OVR",
                             spoken: "overall", width: 44)]
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
