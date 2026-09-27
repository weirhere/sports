import Foundation

/// Who a head coach is, as the door that opened their page knew them — the
/// Roster tab's Coach card knows an id, a name and the team (E27,
/// 2026-09-27). `PlayerIdentity`'s shape, for its reasons: the page paints
/// from this immediately and `CoachClient` fills in the rest.
///
/// **Head coaches only.** ESPN lists exactly one coach per team-season in
/// every league (`count: 1`, `?role=all` changes nothing, `/staff` 404s —
/// probed 2026-09-27), so there is no coordinator to open a page for.
nonisolated struct CoachIdentity: Sendable, Hashable, Identifiable {
    /// ESPN's coach id, which is **per league**: Jim Harbaugh is NFL `27`,
    /// and `college-football/coaches/27` 404s. A college career and a pro
    /// one are two ids with nothing joining them, so this page shows the
    /// league it was opened from.
    let coachId: String
    let name: String
    let league: League
    var team: Team?

    /// Namespaced by league, `PlayerIdentity.id`'s rule: this is a
    /// navigation identity, and two leagues reuse ids.
    var id: String { "\(league.rawValue)-coach-\(coachId)" }
}

/// Everything ESPN's core API holds about one head coach.
nonisolated struct CoachProfile: Sendable, Equatable {
    var name: String
    var headshotURL: URL?
    var dateOfBirth: Date?
    var birthPlace: String?
    /// Alma mater — "Temple".
    var college: String?
    /// ESPN's `experience`, a bare integer it never labels. Shown as it
    /// is, under ESPN's own word.
    var experience: Int?
    /// Total, Regular season and Postseason, in that order, each present
    /// only when ESPN sent it. College football sends no postseason split.
    var records: [CoachRecord]
    /// Newest first, one per season the coach held the job, zero-game
    /// seasons and ESPN's duplicate rows removed.
    var seasons: [CoachSeason]

    static let empty = CoachProfile(name: "", records: [], seasons: [])

    /// Whole years on `now`, or nil without a birth date (college coaches
    /// carry none).
    func age(on now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let dateOfBirth else { return nil }
        return calendar.dateComponents([.year], from: dateOfBirth, to: now).year
    }

    /// The seasons grouped into stints — consecutive seasons at one team —
    /// newest first. "Where they coached before", read as a list of jobs.
    var stints: [CoachStint] {
        var out: [CoachStint] = []
        for season in seasons {
            if let last = out.last, last.teamId == season.teamId,
               let earliest = last.seasons.last?.year, earliest - season.year == 1 {
                out[out.count - 1].seasons.append(season)
            } else {
                out.append(CoachStint(teamId: season.teamId, seasons: [season]))
            }
        }
        return out
    }
}

/// A win-loss line, built from ESPN's named stats rather than its
/// `summary` string, which is W-L-T in football ("59-74-0") and
/// W-L-T-OTL in hockey ("1072-671-77-159").
nonisolated struct CoachRecord: Sendable, Equatable, Identifiable {
    enum Kind: Int, Sendable, Comparable {
        case total, regular, postseason

        static func < (a: Kind, b: Kind) -> Bool { a.rawValue < b.rawValue }

        var title: String {
            switch self {
            case .total: "Career"
            case .regular: "Regular season"
            case .postseason: "Postseason"
            }
        }
    }

    let kind: Kind
    let wins: Int
    let losses: Int
    let ties: Int
    /// Hockey's overtime losses, which ESPN counts apart from `losses`.
    /// Football carries the stat too, but there its overtime losses are
    /// already inside `losses`, so it is only read for the NHL.
    let overtimeLosses: Int

    var id: Kind { kind }

    var games: Int { wins + losses + ties + overtimeLosses }

    /// "59-74", "8-9-1" with a tie, "1072-671-77-159" for hockey's old ties
    /// beside its overtime losses. A zero ties column is dropped, the way
    /// every standings table in the app already spells a record.
    var summary: String {
        var parts = [wins, losses]
        if ties > 0 { parts.append(ties) }
        if overtimeLosses > 0 { parts.append(overtimeLosses) }
        return parts.map(String.init).joined(separator: "-")
    }

    /// Wins over games, a tie counting half in football — the NFL's own
    /// definition. Hockey's overtime losses are games lost. Nil with no
    /// games, where a ".000" would claim a record that doesn't exist.
    var winPercent: Double? {
        guard games > 0 else { return nil }
        return (Double(wins) + Double(ties) / 2) / Double(games)
    }

    /// ".541" — the standings tables' PCT spelling.
    var winPercentText: String? {
        winPercent.map { String(format: "%.3f", $0).replacingOccurrences(of: "0.", with: ".") }
    }
}

/// One season in the job.
nonisolated struct CoachSeason: Sendable, Equatable, Identifiable {
    /// Our opening-year axis — `League.seasonYear(fromESPN:)` is applied at
    /// the client boundary, so an NBA "2026" arrives here as 2025.
    let year: Int
    let teamId: String
    /// ESPN's regular-season line. ESPN publishes no per-season postseason
    /// record (`types/3/.../record` 404s even for a playoff year).
    let record: CoachRecord?

    var id: String { "\(year)-\(teamId)" }
}

nonisolated struct CoachStint: Sendable, Equatable, Identifiable {
    let teamId: String
    /// Newest first.
    var seasons: [CoachSeason]

    var id: String { "\(teamId)-\(seasons.first?.year ?? 0)" }

    /// "2022–2026", or "2016" for a single season, on the league's axis.
    func span(league: League) -> String {
        guard let newest = seasons.first?.year, let oldest = seasons.last?.year else { return "" }
        if newest == oldest { return league.seasonLabel(newest) }
        return "\(league.seasonLabel(oldest))–\(league.seasonLabel(newest))"
    }

    /// The stint's regular seasons summed — the app's only arithmetic on a
    /// coach, since ESPN keeps no per-job total.
    var record: CoachRecord? {
        let lines = seasons.compactMap(\.record)
        guard !lines.isEmpty else { return nil }
        return CoachRecord(kind: .regular,
                           wins: lines.map(\.wins).reduce(0, +),
                           losses: lines.map(\.losses).reduce(0, +),
                           ties: lines.map(\.ties).reduce(0, +),
                           overtimeLosses: lines.map(\.overtimeLosses).reduce(0, +))
    }
}
