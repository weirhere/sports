import Foundation

/// CFBD DTO → domain mapping. Pure functions so unit tests can drive them
/// with fixture JSON and no network.
nonisolated enum CFBDMapper {

    // MARK: - Season types & weeks

    /// Domain season types keep ESPN's numbering (2 regular, 3 postseason)
    /// so WeekSlot ids and persisted UI state survive a backend switch.
    static func seasonTypeName(_ value: Int) -> String {
        value == 3 ? "postseason" : "regular"
    }

    static func seasonTypeValue(_ name: String?) -> Int? {
        switch name {
        case "regular": return 2
        case "postseason": return 3
        default: return nil
        }
    }

    static func weekSlots(from weeks: [CFBDCalendarWeekDTO]) -> [WeekSlot] {
        let mapped = weeks.compactMap { week -> WeekSlot? in
            guard let value = week.week,
                  let type = seasonTypeValue(week.seasonType) else { return nil }
            let label = type == 3
                ? (weeks.filter { $0.seasonType == "postseason" }.count > 1 ? "Postseason \(value)" : "Postseason")
                : "Week \(value)"
            return WeekSlot(
                label: label,
                shortLabel: type == 3 ? "Post" : "\(value)",
                seasonType: type,
                value: value,
                startDate: CFBDDate.parse(week.startDate),
                endDate: CFBDDate.parse(week.endDate)
            )
        }
        return mapped.sorted {
            ($0.seasonType, $0.value) < ($1.seasonType, $1.value)
        }
    }

    /// CFBD has no "current week" field; derive it from the calendar. The
    /// slot containing now wins; between weeks, the next upcoming one.
    static func currentSlot(in slots: [WeekSlot], now: Date = .now) -> WeekSlot? {
        slots.first { $0.contains(now) }
            ?? slots.first { ($0.startDate ?? .distantPast) > now }
            ?? slots.last
    }

    // MARK: - Games

    static func game(
        from dto: CFBDGameDTO,
        live: CFBDScoreboardGameDTO?,
        media: [CFBDGameMediaDTO],
        joins: CFBDJoins
    ) -> Game? {
        guard let id = dto.id,
              let homeId = dto.homeId, let homeSchool = dto.homeTeam,
              let awayId = dto.awayId, let awaySchool = dto.awayTeam
        else { return nil }

        let home = team(id: homeId, school: homeSchool, conferenceName: dto.homeConference, joins: joins)
        let away = team(id: awayId, school: awaySchool, conferenceName: dto.awayConference, joins: joins)

        let broadcast = live?.tv ?? media
            .filter { $0.id == id }
            .sorted { ($0.mediaType == "tv" ? 0 : 1) < ($1.mediaType == "tv" ? 0 : 1) }
            .first?.outlet

        return Game(
            id: String(id),
            date: CFBDDate.parse(dto.startDate),
            timeTBD: dto.startTimeTBD == true,
            name: "\(awaySchool) at \(homeSchool)",
            shortName: shortName(away: away, home: home),
            weekNumber: dto.week,
            seasonType: seasonTypeValue(dto.seasonType),
            status: status(from: dto, live: live, homeId: homeId, awayId: awayId),
            home: competitor(dto: dto, live: live, team: home, id: homeId, isHome: true, joins: joins),
            away: competitor(dto: dto, live: live, team: away, id: awayId, isHome: false, joins: joins),
            broadcast: broadcast
        )
    }

    private static func shortName(away: Team, home: Team) -> String? {
        guard let a = away.abbreviation, let h = home.abbreviation else { return nil }
        return "\(a) @ \(h)"
    }

    static func status(
        from dto: CFBDGameDTO,
        live: CFBDScoreboardGameDTO?,
        homeId: Int,
        awayId: Int
    ) -> GameStatus {
        if let live, live.status == "in_progress" {
            // CFBD has no halftime status — infer it from a run-out
            // second-quarter clock, and stay conservative elsewhere
            // (an end-of-quarter guess in Q4 could mislabel a game
            // heading to OT).
            let halftime = live.period == 2
                && (live.clock == "0:00" || live.clock == "00:00")
            return .live(
                displayClock: live.clock,
                period: live.period,
                detail: live.period.map { "Q\($0)" },
                phase: halftime ? .halftime : .playing,
                possessionTeamId: possessionTeamId(live.possession, homeId: homeId, awayId: awayId)
            )
        }
        if dto.completed == true || live?.status == "completed" {
            let overtime = (dto.homeLineScores?.count ?? 0) > 4
            return .final(detail: overtime ? "Final OT" : "Final")
        }
        return .pre(detail: dto.startTimeTBD == true ? "TBD" : nil)
    }

    /// CFBD's scoreboard says "home"/"away"; the domain wants a team id.
    static func possessionTeamId(_ possession: String?, homeId: Int, awayId: Int) -> String? {
        switch possession {
        case "home": return String(homeId)
        case "away": return String(awayId)
        default: return nil
        }
    }

    private static func competitor(
        dto: CFBDGameDTO,
        live: CFBDScoreboardGameDTO?,
        team: Team,
        id: Int,
        isHome: Bool,
        joins: CFBDJoins
    ) -> Competitor {
        let gamePoints = isHome ? dto.homePoints : dto.awayPoints
        let livePoints = isHome ? live?.homeTeam?.points : live?.awayTeam?.points
        let score = livePoints ?? gamePoints
        var winner: Bool?
        if dto.completed == true, let homePoints = dto.homePoints, let awayPoints = dto.awayPoints,
           homePoints != awayPoints {
            winner = isHome ? homePoints > awayPoints : awayPoints > homePoints
        }
        return Competitor(
            team: team,
            score: score,
            record: joins.records[id],
            rank: joins.ranks[id].flatMap { (1...25).contains($0) ? $0 : nil },
            isHome: isHome,
            winner: winner
        )
    }

    // MARK: - Teams

    static func team(
        id: Int,
        school: String,
        conferenceName: String?,
        joins: CFBDJoins
    ) -> Team {
        let meta = joins.byId[id]
        return team(from: meta, fallbackId: id, fallbackSchool: school,
                    fallbackConference: conferenceName)
    }

    static func team(
        from meta: CFBDTeamDTO?,
        fallbackId: Int? = nil,
        fallbackSchool: String? = nil,
        fallbackConference: String? = nil
    ) -> Team {
        let id = meta?.id ?? fallbackId ?? -1
        let school = meta?.school ?? fallbackSchool ?? "—"
        let mascot = meta?.mascot
        return Team(
            id: String(id),
            location: school,
            name: mascot,
            abbreviation: meta?.abbreviation,
            displayName: mascot.map { "\(school) \($0)" } ?? school,
            shortDisplayName: school,
            logoURL: logoURL(meta?.logos),
            conferenceId: Conference.id(forCFBDName: meta?.conference ?? fallbackConference)
        )
    }

    /// CFBD serves logo URLs with an http scheme; ATS would block them.
    static func logoURL(_ logos: [String]?) -> URL? {
        guard let first = logos?.first else { return nil }
        return URL(string: first.replacingOccurrences(of: "http://", with: "https://"))
    }

    static func conferences(from teams: [CFBDTeamDTO]) -> [ConferenceTeams] {
        let grouped = Dictionary(grouping: teams.filter { $0.conference != nil }) {
            $0.conference ?? ""
        }
        return grouped.compactMap { name, members -> ConferenceTeams? in
            let id = Conference.id(forCFBDName: name)
            let mapped = members.compactMap { member -> Team? in
                guard member.id != nil else { return nil }
                return team(from: member)
            }
            guard !mapped.isEmpty else { return nil }
            return ConferenceTeams(
                id: id,
                name: id != nil ? Conference.name(for: id) : name,
                teams: mapped.sorted { $0.location < $1.location }
            )
        }
        .sorted { lhs, rhs in
            let (lt, rt) = (Conference.tier(for: lhs.id), Conference.tier(for: rhs.id))
            return lt == rt ? lhs.name < rhs.name : lt < rt
        }
    }

    /// CFBD has no authoritative standings order (no tiebreakers), so this
    /// sorts by conference win pct, then overall win pct, then school — a
    /// documented deviation from ESPN's order. No streak data either.
    static func conferenceStandings(from teams: [CFBDTeamDTO],
                                    records: [CFBDTeamRecordsDTO]) -> [ConferenceStandings] {
        let recordsById = Dictionary(records.compactMap { dto in
            dto.teamId.map { ($0, dto) }
        }, uniquingKeysWith: { first, _ in first })

        func summary(_ record: CFBDRecordDTO?) -> String? {
            guard let wins = record?.wins, let losses = record?.losses else { return nil }
            let ties = record?.ties ?? 0
            return ties > 0 ? "\(wins)-\(losses)-\(ties)" : "\(wins)-\(losses)"
        }
        func winPct(_ record: CFBDRecordDTO?) -> Double {
            guard let wins = record?.wins, let losses = record?.losses else { return -1 }
            let games = wins + losses + (record?.ties ?? 0)
            return games > 0 ? Double(wins) / Double(games) : 0
        }

        let grouped = Dictionary(grouping: teams.filter { $0.conference != nil }) {
            $0.conference ?? ""
        }
        return grouped.compactMap { name, members -> ConferenceStandings? in
            let id = Conference.id(forCFBDName: name)
            let entries = members.compactMap { member -> (ConferenceStanding, Double, Double)? in
                guard member.id != nil else { return nil }
                let record = member.id.flatMap { recordsById[$0] }
                let standing = ConferenceStanding(
                    team: team(from: member),
                    conferenceRecord: summary(record?.conferenceGames),
                    overallRecord: summary(record?.total),
                    streak: nil
                )
                return (standing, winPct(record?.conferenceGames), winPct(record?.total))
            }
            guard !entries.isEmpty else { return nil }
            let sorted = entries.sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.2 != rhs.2 { return lhs.2 > rhs.2 }
                return lhs.0.team.location < rhs.0.team.location
            }
            return ConferenceStandings(
                id: id,
                name: id != nil ? Conference.name(for: id) : name,
                entries: sorted.map(\.0)
            )
        }
        .sorted { lhs, rhs in
            let (lt, rt) = (Conference.tier(for: lhs.id), Conference.tier(for: rhs.id))
            return lt == rt ? lhs.name < rhs.name : lt < rt
        }
    }

    static func recordsById(from records: [CFBDTeamRecordsDTO]) -> [Int: String] {
        var result: [Int: String] = [:]
        for record in records {
            guard let id = record.teamId, let total = record.total,
                  let wins = total.wins, let losses = total.losses else { continue }
            let ties = total.ties ?? 0
            result[id] = ties > 0 ? "\(wins)-\(losses)-\(ties)" : "\(wins)-\(losses)"
        }
        return result
    }

    // MARK: - Rankings

    /// The FBS polls the UI knows, mapped onto the domain's ESPN-era type
    /// keys so the picker and persisted choice keep working.
    private static let pollTypes: [(cfbdName: String, type: String, shortName: String)] = [
        ("AP Top 25", "ap", "AP"),
        ("Coaches Poll", "usa", "Coaches"),
        ("Playoff Committee Rankings", "cfp", "CFP"),
    ]

    static func polls(from weeks: [CFBDPollWeekDTO], season: Int, joins: CFBDJoins) -> [Poll] {
        let ordered = weeks
            .filter { !($0.polls ?? []).isEmpty }
            .sorted { sortKey($0) < sortKey($1) }
        guard let latest = ordered.last else { return [] }
        let previous = ordered.dropLast().last

        return pollTypes.compactMap { mapping in
            guard let poll = latest.polls?.first(where: { $0.poll == mapping.cfbdName }) else {
                return nil
            }
            let previousRanks = previous?.polls?
                .first { $0.poll == mapping.cfbdName }?.ranks ?? []
            let ranks = (poll.ranks ?? []).compactMap { rank -> RankedTeam? in
                guard let current = rank.rank, let teamId = rank.teamId else { return nil }
                let team = team(from: joins.byId[teamId], fallbackId: teamId,
                                fallbackSchool: rank.school)
                return RankedTeam(
                    team: team,
                    current: current,
                    previous: previousRanks.first { $0.teamId == teamId }?.rank,
                    points: rank.points,
                    firstPlaceVotes: rank.firstPlaceVotes,
                    record: joins.records[teamId]
                )
            }
            guard !ranks.isEmpty else { return nil }
            return Poll(
                id: mapping.type,
                name: mapping.cfbdName,
                shortName: mapping.shortName,
                type: mapping.type,
                headline: headline(for: latest, season: season, pollName: mapping.cfbdName),
                ranks: ranks.sorted { $0.current < $1.current }
            )
        }
    }

    private static func sortKey(_ week: CFBDPollWeekDTO) -> (Int, Int) {
        (week.seasonType == "postseason" ? 1 : 0, week.week ?? 0)
    }

    private static func headline(for week: CFBDPollWeekDTO, season: Int, pollName: String) -> String {
        if week.seasonType == "postseason" {
            return "\(season) \(pollName): Final Rankings"
        }
        return "\(season) \(pollName): Week \(week.week ?? 0)"
    }

    /// Rank badges for game rows: CFP committee when it exists, else AP.
    static func rankBadges(from weeks: [CFBDPollWeekDTO], week: Int?) -> [Int: Int] {
        let ordered = weeks
            .filter { !($0.polls ?? []).isEmpty }
            .sorted { sortKey($0) < sortKey($1) }
        let target = week.flatMap { value in ordered.last { $0.week == value } } ?? ordered.last
        guard let target else { return [:] }
        let poll = target.polls?.first { $0.poll == "Playoff Committee Rankings" }
            ?? target.polls?.first { $0.poll == "AP Top 25" }
        var result: [Int: Int] = [:]
        for rank in poll?.ranks ?? [] {
            if let id = rank.teamId, let value = rank.rank {
                result[id] = value
            }
        }
        return result
    }

    // MARK: - Team schedule

    static func teamSchedule(
        team meta: CFBDTeamDTO,
        games: [CFBDGameDTO],
        joins: CFBDJoins,
        year: Int
    ) -> TeamSchedule {
        let mapped = games.compactMap { game(from: $0, live: nil, media: [], joins: joins) }
        return TeamSchedule(
            team: team(from: meta),
            // The /records join is scoped to the requested year, so it's
            // honest for past seasons — no ESPN-style trust rule needed.
            record: meta.id.flatMap { joins.records[$0] },
            standing: nil,
            year: year,
            games: mapped.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        )
    }

    // MARK: - Game summary

    static func gameSummary(
        game dto: CFBDGameDTO,
        live: CFBDScoreboardGameDTO?,
        stats: CFBDGameTeamStatsDTO?,
        players: CFBDGamePlayerStatsDTO?,
        drives: [CFBDDriveDTO],
        joins: CFBDJoins
    ) -> GameSummary {
        let homeId = dto.homeId
        let awayId = dto.awayId

        func side(isHome: Bool) -> GameSummary.Side? {
            guard let id = isHome ? homeId : awayId,
                  let school = isHome ? dto.homeTeam : dto.awayTeam else { return nil }
            let team = team(id: id, school: school,
                            conferenceName: isHome ? dto.homeConference : dto.awayConference,
                            joins: joins)
            let gamePoints = isHome ? dto.homePoints : dto.awayPoints
            let livePoints = isHome ? live?.homeTeam?.points : live?.awayTeam?.points
            var winner: Bool?
            if dto.completed == true, let home = dto.homePoints, let away = dto.awayPoints,
               home != away {
                winner = isHome ? home > away : away > home
            }
            let lineScores = (isHome ? dto.homeLineScores : dto.awayLineScores) ?? []
            return GameSummary.Side(
                team: team,
                score: livePoints ?? gamePoints,
                record: joins.records[id],
                rank: joins.ranks[id].flatMap { (1...25).contains($0) ? $0 : nil },
                winner: winner,
                linescores: lineScores.map { String(Int($0)) }
            )
        }

        return GameSummary(
            home: side(isHome: true),
            away: side(isHome: false),
            status: status(from: dto, live: live, homeId: homeId ?? -1, awayId: awayId ?? -1),
            scoringPlays: scoringPlays(from: drives, joins: joins),
            drives: drives.enumerated().map { index, drive in
                Drive(
                    id: drive.id ?? "drive-\(index)",
                    teamId: drive.offense.flatMap { joins.bySchool[$0]?.id.map(String.init) },
                    result: drive.driveResult,
                    isScore: drive.scoring ?? false,
                    summary: driveSummary(drive),
                    period: drive.startPeriod
                )
            },
            teamStats: teamStats(from: stats),
            leaders: leaders(from: players),
            venue: dto.venue,
            attendance: dto.attendance
        )
    }

    private static func driveSummary(_ drive: CFBDDriveDTO) -> String? {
        guard let plays = drive.plays, let yards = drive.yards else { return nil }
        return "\(plays) plays, \(yards) yards"
    }

    /// CFBD has no scoring-plays feed at Tier 1; scoring drives stand in.
    /// Text degrades from ESPN's play description to the drive outcome.
    static func scoringPlays(from drives: [CFBDDriveDTO], joins: CFBDJoins) -> [ScoringPlay] {
        drives.filter { $0.scoring == true }.enumerated().map { index, drive in
            let offenseScore = drive.endOffenseScore
            let defenseScore = drive.endDefenseScore
            let isHomeOffense = drive.isHomeOffense ?? false
            return ScoringPlay(
                id: drive.id ?? "score-\(index)",
                period: drive.endPeriod,
                clock: nil,
                text: [drive.offense, drive.driveResult?.capitalized, driveSummary(drive)]
                    .compactMap { $0 }.joined(separator: " — "),
                typeAbbreviation: scoreType(drive.driveResult),
                teamId: drive.offense.flatMap { joins.bySchool[$0]?.id.map(String.init) },
                awayScore: isHomeOffense ? defenseScore : offenseScore,
                homeScore: isHomeOffense ? offenseScore : defenseScore
            )
        }
    }

    private static func scoreType(_ result: String?) -> String? {
        guard let result = result?.uppercased() else { return nil }
        if result.contains("TD") || result.contains("TOUCHDOWN") { return "TD" }
        if result.contains("FG") || result.contains("FIELD GOAL") { return "FG" }
        if result.contains("SF") || result.contains("SAFETY") { return "SF" }
        return nil
    }

    /// Same comparison categories as the ESPN path — CFBD kept ESPN's
    /// camelCase category names, so the list transfers verbatim.
    private static let comparedStats: [(name: String, label: String)] = [
        ("totalYards", "Total Yards"),
        ("netPassingYards", "Passing"),
        ("rushingYards", "Rushing"),
        ("thirdDownEff", "3rd Down"),
        ("turnovers", "Turnovers"),
        ("possessionTime", "Possession"),
    ]

    static func teamStats(from dto: CFBDGameTeamStatsDTO?) -> [StatComparison] {
        let teams = dto?.teams ?? []
        guard let away = teams.first(where: { $0.homeAway == "away" }),
              let home = teams.first(where: { $0.homeAway == "home" }) else { return [] }

        func value(_ category: String, of team: CFBDGameTeamStatsTeamDTO) -> String? {
            team.stats?.first { $0.category == category }?.stat
        }

        return comparedStats.compactMap { stat in
            guard let awayDisplay = value(stat.name, of: away),
                  let homeDisplay = value(stat.name, of: home) else { return nil }
            return StatComparison(
                id: stat.name,
                label: stat.label,
                away: awayDisplay,
                home: homeDisplay,
                awayValue: ESPNMapper.statMagnitude(awayDisplay),
                homeValue: ESPNMapper.statMagnitude(homeDisplay)
            )
        }
    }

    private static let leaderCategories: [(cfbdName: String, id: String, label: String)] = [
        ("passing", "passingYards", "Passing"),
        ("rushing", "rushingYards", "Rushing"),
        ("receiving", "receivingYards", "Receiving"),
    ]

    static func leaders(from dto: CFBDGamePlayerStatsDTO?) -> [LeaderCategory] {
        func leader(homeAway: String, category: String) -> LeaderCategory.Leader? {
            guard let team = dto?.teams?.first(where: { $0.homeAway == homeAway }),
                  let yards = team.categories?
                      .first(where: { $0.name == category })?.types?
                      .first(where: { $0.name == "YDS" })?.athletes?
                      .max(by: { (Double($0.stat ?? "") ?? 0) < (Double($1.stat ?? "") ?? 0) }),
                  let name = yards.name
            else { return nil }
            return LeaderCategory.Leader(name: name, statLine: "\(yards.stat ?? "0") yds")
        }

        return leaderCategories.compactMap { category in
            let away = leader(homeAway: "away", category: category.cfbdName)
            let home = leader(homeAway: "home", category: category.cfbdName)
            guard away != nil || home != nil else { return nil }
            return LeaderCategory(id: category.id, label: category.label, away: away, home: home)
        }
    }
}
