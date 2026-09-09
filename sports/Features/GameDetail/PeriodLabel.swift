import Foundation

/// The period marker the scoring list and the play log both print above a
/// run of rows. One copy — the two lists carried it verbatim.
///
/// What a period is called is the league's: four quarters in football and
/// basketball, three periods in hockey. Past regulation every league says
/// "OVERTIME" and then counts, with one exception — the NHL settles a
/// regular-season tie in a shootout after the overtime, which arrives as
/// period 5 (verified live 2026-09-08: `Final/SO`, `altDetail: "SO"`).
/// A playoff period 5 is a second overtime, so the shootout label is only
/// ever offered where the game could actually have one.
enum PeriodLabel {
    static func text(_ period: Int?, in league: League = .collegeFootball,
                     allowsShootout: Bool = false) -> String {
        guard let period else { return "—" }
        let format = league.periodFormat
        if period <= format.regulationCount {
            return "\(ordinal(period)) \(format.longName)"
        }
        if period == format.regulationCount + 1 { return "OVERTIME" }
        if allowsShootout, period == format.regulationCount + 2 { return "SHOOTOUT" }
        return "\(period - format.regulationCount)OT"
    }

    /// The short form the line-score header and the live clock use: "3",
    /// "OT", "SO".
    static func short(_ period: Int, in league: League,
                      allowsShootout: Bool = false) -> String {
        let format = league.periodFormat
        if period <= format.regulationCount { return "\(period)" }
        if period == format.regulationCount + 1 { return "OT" }
        if allowsShootout, period == format.regulationCount + 2 { return "SO" }
        return "\(period - format.regulationCount)OT"
    }

    private static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: "1ST"
        case 2: "2ND"
        case 3: "3RD"
        default: "\(n)TH"
        }
    }
}
