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
        if league.isBaseball { return "\(ordinal(period)) \(format.longName)" }
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
        // Extra innings are innings: the line score's tenth column is "10".
        if league.isBaseball { return "\(period)" }
        let format = league.periodFormat
        if period <= format.regulationCount { return "\(period)" }
        if period == format.regulationCount + 1 { return "OT" }
        if allowsShootout, period == format.regulationCount + 2 { return "SO" }
        return "\(period - format.regulationCount)OT"
    }

    /// A half-inning, for baseball's plays list: "TOP 1ST", "BOTTOM 9TH"
    /// (2026-11-03).
    static func halfInning(_ period: Int?, half: InningHalf) -> String {
        guard let period else { return half.title.uppercased() }
        return "\(half.title.uppercased()) \(ordinal(period))"
    }

    private static func ordinal(_ n: Int) -> String {
        // Teens are all "TH" — the 11th, 12th and 13th innings exist.
        guard !(11...13).contains(n % 100) else { return "\(n)TH" }
        switch n % 10 {
        case 1: return "\(n)ST"
        case 2: return "\(n)ND"
        case 3: return "\(n)RD"
        default: return "\(n)TH"
        }
    }
}
