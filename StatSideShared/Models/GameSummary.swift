import Foundation

/// Everything the game-detail screen renders, mapped from ESPN's summary.
nonisolated struct GameSummary: Sendable {
    struct Side: Hashable, Sendable {
        let team: Team
        let score: Int?
        let record: String?
        let rank: Int?
        let winner: Bool?
        let linescores: [String]   // per-quarter, incl. OT columns
        /// ESPN's team colors, bare hex. The Gamecast field paints its
        /// end zones with them and nothing else does (2026-09-27). On the
        /// side rather than `Team` so a team's identity, which follows and
        /// merges compare, doesn't change with the payload it came from.
        var color: String? = nil
        var alternateColor: String? = nil
    }

    let home: Side?
    let away: Side?
    let status: GameStatus
    let scoringPlays: [ScoringPlay]
    let drives: [Drive]
    /// The possession in progress, live games only — ESPN's
    /// `drives.current`. Nil the moment a game is final, which is what
    /// retires the situation card without a second condition.
    var currentDrive: Drive? = nil
    let teamStats: [StatComparison]
    let leaders: [LeaderCategory]
    /// Defaulted so CFBD (no player feed) and every fixture construct
    /// unchanged — empty is what hides the Box score tab.
    var boxScore: [BoxScore] = []
    /// The flat play feed, oldest first. Only populated for leagues with
    /// no drives to group by — football's plays live inside `drives`, and
    /// carrying them twice would print the same rows in two places.
    /// Defaulted so every fixture and the CFBD mapper construct unchanged.
    var plays: [Play] = []
    let venue: String?
    let attendance: Int?
    /// The pre-game info card's extras — every field optional, defaulted
    /// so fixtures and older call sites construct unchanged.
    var venueCity: String? = nil
    var venueCapacity: Int? = nil
    var grassSurface: Bool? = nil
    var weatherCondition: String? = nil
    var weatherTemperature: Int? = nil
    /// The pre-game line — spread (or hockey's moneyline) and the total,
    /// as ESPN leads with them. Nil when the summary carries no line.
    var line: GameLine? = nil
    /// The two sides' own standings tables, read out of the summary
    /// rather than fetched (E21, 2026-09-21). Empty for every league
    /// whose summary ships a division instead of a conference, and for
    /// CFBD, which ships no standings block at all — the game page falls
    /// back to `conferenceStandings()` when this is empty, so an absent
    /// block costs a request, never the card.
    var matchupStandings: [ConferenceStandings] = []
    /// The win-probability card's data (Coard Miller, 2026-09-24). Nil
    /// wherever the payload has neither block, which is how the card hides
    /// itself for hockey.
    var winProbability: WinProbability? = nil
    /// The game's own story, body included: a Preview before kickoff, a
    /// Recap once final (docs/news.md, N2 and N3). Nil for CFBD and every
    /// fixture, and for a live game, whose summary ships none.
    var article: NewsStory? = nil
}

/// Who's likely to win, as ESPN models it. Two shapes, because the payload
/// has two: a single projection before kickoff, and a line through every
/// play once the game is under way.
nonisolated enum WinProbability: Hashable, Sendable {
    /// ESPN's matchup predictor, in percent (55.6, 44.4).
    case pregame(home: Double, away: Double)
    /// The home side's chance after each play, 0...1, oldest first.
    case series([Double])

    /// The series once it has a line to draw (two points or more), else
    /// the predictor, else nothing.
    init?(predictor: (home: Double?, away: Double?)?, series: [Double]) {
        let clamped = series.map { min(max($0, 0), 1) }
        if clamped.count >= 2 {
            self = .series(clamped)
        } else if let home = predictor?.home, let away = predictor?.away,
                  home >= 0, away >= 0, home + away > 0 {
            self = .pregame(home: home, away: away)
        } else {
            return nil
        }
    }

    /// The home side's current chance, in percent.
    var homePercent: Double {
        switch self {
        case .pregame(let home, let away): home / (home + away) * 100
        case .series(let points): (points.last ?? 0.5) * 100
        }
    }
}

/// A game's betting line, narrowed to the two numbers a fan picks games
/// by (Coard Miller, 2026-09-24): ESPN's headline line and the total. No
/// provider, no moneyline column, no bet links — the rest of `pickcenter`
/// stays iced (BACKLOG, "There, large, and deliberately not ours").
nonisolated struct GameLine: Hashable, Sendable {
    let details: String?
    let overUnder: Double?
    /// Who was favored, where the payload says (the scoreboard's per-team
    /// `favorite`; the summary's `pickcenter` isn't read for it). The Tight
    /// filter's underdog rule needs it; nothing prints it.
    var favoriteIsHome: Bool? = nil

    /// Nil when neither half survived, so an empty line has no row.
    init?(details: String?, overUnder: Double?, favoriteIsHome: Bool? = nil) {
        let trimmed = details?.trimmingCharacters(in: .whitespaces)
        let details = trimmed?.isEmpty == false ? trimmed : nil
        guard details != nil || overUnder != nil else { return nil }
        self.details = details
        self.overUnder = overUnder
        self.favoriteIsHome = favoriteIsHome
    }

    /// "IU -7.5 · O/U 47.5", dropping whichever half is missing.
    var text: String {
        [details, overUnder.map { "O/U \(Self.number($0))" }]
            .compactMap(\.self).joined(separator: " · ")
    }

    /// The same line spoken: "O/U" read aloud is a slash.
    var accessibilityText: String {
        [details, overUnder.map { "over under \(Self.number($0))" }]
            .compactMap(\.self).joined(separator: ", ")
    }

    /// 47.5 stays 47.5; 6.0 prints as 6, the way a total is quoted.
    static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}

extension GameSummary {
    /// The side whose team carries this id. Both the drive log and the
    /// scoring list resolve a play's team this way.
    func team(withId id: String?) -> Team? {
        guard let id else { return nil }
        return [away, home].compactMap(\.self).first { $0.team.id == id }?.team
    }
}

/// One offensive possession, chronological. `summary` is ESPN's pre-built
/// "5 plays, 20 yards, 2:39" line — no reassembly needed.
nonisolated struct Drive: Identifiable, Hashable, Sendable {
    let id: String
    let teamId: String?
    let result: String?      // "Punt", "Field Goal", "Touchdown"
    let isScore: Bool
    let summary: String?
    let period: Int?         // quarter the drive started in
    /// Chronological, as ESPN ships them. Defaulted so CFBD's drive feed
    /// and every fixture construct unchanged — an empty array is what
    /// leaves a drive row unexpandable.
    var plays: [Play] = []
    /// `summary`'s parts, for the current drive card's Drive column.
    /// Defaulted for CFBD and the fixtures, which fall back to `summary`.
    var offensivePlays: Int? = nil
    var yards: Int? = nil
    /// "2:39", the Plays tab row's time column.
    var timeElapsed: String? = nil
}

extension Drive {
    /// The last score this drive put up, with whose points they were —
    /// the Plays tab row prints it after the result. Nil on a drive that
    /// scored nothing, and on one whose numbers ESPN didn't ship.
    var runningScore: (away: Int, home: Int, side: ScoringSide?)? {
        guard let play = scoringPlays.last,
              let away = play.awayScore, let home = play.homeScore else { return nil }
        return (away, home, play.scoringSide)
    }
}

/// One play inside a drive: ESPN's play-by-play row, and the source of
/// the live situation strip (the current drive's last play knows the
/// down, the ball's spot, and how far it is from the end zone).
nonisolated struct Play: Identifiable, Hashable, Sendable {
    let id: String
    /// ESPN's own narration — "Shotgun #15 F.Mendoza pass complete
    /// short right to #3 O.Cooper for 11 yards". ESPN leads it with the
    /// clock in parentheses; the mapper strips that, since every surface
    /// that prints the text prints `clock` beside it.
    let text: String?
    /// The down the play began on, ESPN's string: "1st & 10 at IU 5".
    let downDistanceText: String?
    /// The down the play *left* behind, short form: "2nd & 4". What the
    /// situation strip says, since it describes what happens next.
    let nextDownDistanceText: String?
    /// Where the ball sits after the play — "WSU 26".
    let possessionText: String?
    /// Distance from the offense's target end zone once the play ended.
    /// The field bar's only number; nil leaves the bar off.
    let yardsToEndzone: Int?
    let clock: String?
    let period: Int?
    /// "Pass Reception", "Field Goal Good".
    let typeText: String?
    let isScoringPlay: Bool
    let awayScore: Int?
    let homeScore: Int?
    /// Whose points these were, stamped at the client boundary from the
    /// change in the running score. Nil on every non-scoring play, and on
    /// a scoring play whose numbers ESPN didn't ship.
    var scoringSide: ScoringSide? = nil
    /// Whose play it was, where the payload says. Only the flat feed
    /// carries it — a drive's plays belong to the drive's offense.
    var teamId: String? = nil
    /// Distance from the offense's target end zone at the snap — where
    /// the field draws this play's arrow from. Nil when the play changed
    /// hands (a kickoff, a punt, a turnover): the two ends are measured
    /// toward different end zones, so no one arrow joins them.
    var startYardsToEndzone: Int? = nil
    /// Yards to a first down once the play ended — the field's line to
    /// gain. Goal to go when it reaches the end zone.
    var nextDistance: Int? = nil
    /// Whose ball it was when the play ended. Every `yardsToEndzone`
    /// counts toward the end zone *this* team attacks, which isn't always
    /// the drive's: ESPN keeps a punting team's drive as `drives.current`
    /// until the next snap, and the plays after the punt are the
    /// receiver's (probed live, NFL 2026-09-27).
    var endTeamId: String? = nil
    /// Where a basketball or hockey play happened, in ESPN's feet. Nil in
    /// football and on a play ESPN gave no usable spot.
    var coordinate: PlayCoordinate? = nil
    /// ESPN's flag for a shot attempt, free throws included.
    var isShootingPlay: Bool = false
    /// Hockey's manpower, ESPN's abbreviation: "even-strength",
    /// "power-play", "short-handed", "empty-net".
    var strength: String? = nil
}

/// A spot in ESPN's own coordinate space, feet. What each axis means is
/// the league's — see `ShotMap`.
nonisolated struct PlayCoordinate: Hashable, Sendable {
    let x: Double
    let y: Double
}

/// Which side of the matchup a scoring play's points belong to. Read off
/// the score rather than the drive's team on purpose: a pick six and a
/// kick return both score for the side that wasn't on offense.
nonisolated enum ScoringSide: Sendable, Hashable {
    case away, home
}

extension Drive {
    /// The plays that put points on the board. The Plays tab's Scoring
    /// filter narrows to these, and a drive with none drops out entirely.
    var scoringPlays: [Play] { plays.filter(\.isScoringPlay) }
}

nonisolated struct ScoringPlay: Identifiable, Hashable, Sendable {
    let id: String
    let period: Int?
    let clock: String?
    let text: String?
    let typeAbbreviation: String?   // "TD", "FG"
    let teamId: String?
    let awayScore: Int?
    let homeScore: Int?
}

/// One stat compared across both teams, with parsed magnitudes for the
/// opposing bars (nil when the value isn't bar-able).
nonisolated struct StatComparison: Identifiable, Hashable, Sendable {
    let id: String       // ESPN stat name
    let label: String
    let away: String
    let home: String
    let awayValue: Double?
    let homeValue: Double?
}

/// One leader category (Passing / Rushing / Receiving) with each side's leader.
nonisolated struct LeaderCategory: Identifiable, Hashable, Sendable {
    struct Leader: Hashable, Sendable {
        let name: String
        let statLine: String
        /// Defaulted so CFBD's photo-less leaders construct unchanged.
        var headshotURL: URL? = nil
        /// ESPN's athlete id, which `AthleteDTO` has always decoded and this
        /// model dropped until 2026-09-20 (E20). Defaulted for the same
        /// reason as the headshot: `CFBDMapper` builds a leader from a name
        /// and a yardage and has no id to give.
        ///
        /// **Carried, not yet linked.** The web's Leaders card routes on
        /// this because a URL rebuilds the page by re-fetching the team's
        /// roster; iOS hands `PlayerPage` what the calling screen already
        /// knows, and a leader row knows a name, a stat line and a photo.
        /// `profileRows` would come back empty and the page would be a hero
        /// over nothing — thinner than the row that pushed it. The link
        /// lands with the athlete fetch (E20's P0); the id is here so that
        /// is the only thing it waits on.
        var athleteId: String? = nil
    }

    let id: String
    let label: String
    let away: Leader?
    let home: Leader?
}

/// One team's player box score. ESPN ships a category per stat group with
/// its own column headers; we carry those headers through rather than
/// naming columns ourselves, because **the column set changes during the
/// game** — a live `passing` group has five columns and the same group has
/// six once the game is final (QBR only lands at the end). Anything
/// hardcoded here would misalign every row mid-game.
nonisolated struct BoxScore: Identifiable, Hashable, Sendable {
    struct Player: Identifiable, Hashable, Sendable {
        let id: String
        /// ESPN's athlete id, only when ESPN sent one. `id` falls back to a
        /// synthesized `teamId-name` so the row can still be identified in a
        /// `ForEach` — and that fallback must never become a navigation
        /// target, which is why the link reads this instead (2026-09-24).
        var athleteId: String? = nil
        let name: String
        let jersey: String?
        let headshotURL: URL?
        /// Positionally paired with the owning category's `columns`.
        let stats: [String]
    }

    struct Category: Identifiable, Hashable, Sendable {
        let id: String          // ESPN's group name: "passing", "kickReturns"
        let label: String       // "Passing", "Kick Returns"
        let columns: [String]   // "C/ATT", "YDS", "AVG", ...
        let players: [Player]
        /// ESPN's team totals row. Empty when it doesn't match `columns`.
        let totals: [String]
    }

    let teamId: String
    let categories: [Category]

    var id: String { teamId }
}

/// The Gamecast card's content: who has the ball, on what down, where,
/// how the drive got there, and what just happened. Derived entirely from
/// the current drive — one verified shape rather than a second live-only
/// payload.
nonisolated struct GameSituation: Hashable, Sendable {
    let possessionTeamId: String?
    /// "2nd & 4".
    let downDistanceText: String?
    /// "WSU 26" — the ball's spot.
    let possessionText: String?
    /// ESPN's whole drive line: "1 play, 6 yards, 0:05".
    let driveSummary: String?
    /// The Drive column: "4 plays, 57 yds" from the drive's own numbers,
    /// or ESPN's line when they didn't arrive.
    var driveLine: String? = nil
    /// ESPN's narration of the play that just ended.
    let lastPlayText: String?
    /// The down that play faced — "2nd & 15 at WSU 48" — for the Last play
    /// label. The columns above already say where things stand now.
    var lastPlayDownText: String? = nil
    var lastPlayClock: String? = nil
    /// What the field keys its animation on: a new id is a new play, and a
    /// poll that brings the same play back redraws nothing.
    var lastPlayId: String? = nil
    /// Set once the drive has scored — "Touchdown" — and with it the team
    /// whose points they were, which a pick six makes the defense.
    var result: String? = nil
    var resultTeamId: String? = nil
    /// Where the ball sits, 0 at the away team's own goal line and 1 at
    /// the home team's. Nil when the payload gave no distance, which
    /// leaves the field off and the rest of the card standing.
    let fieldPosition: Double?
    /// True when the offense is moving toward the home end zone — the
    /// away team has the ball, so the field's arrow points right.
    let drivingRight: Bool
    var field: Field? = nil

    /// Every spot in yards from the away team's goal line, 0...100, which
    /// is left to right on a field drawn away-end-zone-left.
    struct Field: Hashable, Sendable {
        let ball: Double
        /// The drive's first snap — the trail's hollow dot.
        let driveStart: Double?
        /// Where the last play began. Nil when it changed hands, which
        /// leaves the field showing the ball without an arrow.
        let playStart: Double?
        /// Nil on goal to go, and once the drive has scored.
        let lineToGain: Double?
        /// Passes arc; runs, sacks and penalties travel along the ground.
        let isPass: Bool
    }
}

extension GameSummary {
    /// Nil unless a drive is in progress with a play on it. Everything
    /// here is optional inside ESPN's payload, so a half-filled situation
    /// renders the lines it has and drops the ones it doesn't.
    var situation: GameSituation? {
        guard let drive = currentDrive, let play = drive.plays.last else { return nil }
        // Whose ball it is now, which after a punt isn't the drive's team
        // (see `Play.endTeamId`). Each spot is measured against its own
        // side: `yardsToEndzone` counts down toward the end zone that side
        // attacks. Clamped: a payload can hand back a spot past the goal
        // line on a scoring play.
        let ballTeamId = play.endTeamId ?? drive.teamId
        let handsChanged = ballTeamId != nil && drive.teamId != nil && ballTeamId != drive.teamId
        let isAway = ballTeamId != nil && ballTeamId == away?.team.id
        func fromAwayGoal(_ yardsToEndzone: Int, for teamId: String? = nil) -> Double {
            let side = teamId ?? ballTeamId
            let isAwaySide = side != nil && side == away?.team.id
            return min(max(Double(isAwaySide ? 100 - yardsToEndzone : yardsToEndzone), 0), 100)
        }
        // A snap is never from inside the end zone: a start of 0 is ESPN's
        // filler on a timeout or a review, not a spot. And once the ball
        // has changed hands the drive is over in all but name, so the
        // field shows the ball and the new side's line, no trail or arrow.
        func snapStart(_ play: Play) -> Int? {
            guard !handsChanged, let start = play.startYardsToEndzone, start > 0 else { return nil }
            return start
        }
        let scoring = drive.plays.filter(\.isScoringPlay)
        let result: String? = scoring.isEmpty && !drive.isScore
            ? nil
            : Self.resultName(of: scoring) ?? drive.result ?? "Score"
        let resultTeamId: String? = result == nil ? nil : {
            switch scoring.last?.scoringSide {
            case .away: away?.team.id
            case .home: home?.team.id
            case nil: drive.teamId
            }
        }()
        let field: GameSituation.Field? = play.yardsToEndzone.map { yardsToEndzone in
            let lineToGain: Double? = {
                guard result == nil, let distance = play.nextDistance,
                      distance > 0, distance < yardsToEndzone else { return nil }
                return fromAwayGoal(yardsToEndzone - distance)
            }()
            let type = play.typeText?.lowercased() ?? ""
            let firstSnap = drive.plays.first { snapStart($0) != nil }
            return GameSituation.Field(
                ball: fromAwayGoal(yardsToEndzone),
                driveStart: firstSnap.flatMap(snapStart).map {
                    fromAwayGoal($0, for: firstSnap?.endTeamId ?? drive.teamId)
                },
                playStart: snapStart(play).map { fromAwayGoal($0) },
                lineToGain: lineToGain,
                isPass: type.contains("pass") && !type.contains("sack")
            )
        }
        return GameSituation(
            possessionTeamId: ballTeamId,
            downDistanceText: play.nextDownDistanceText,
            possessionText: play.possessionText,
            driveSummary: drive.summary,
            driveLine: Self.driveLine(drive),
            lastPlayText: play.text,
            lastPlayDownText: play.downDistanceText,
            lastPlayClock: play.clock,
            lastPlayId: play.id,
            result: result,
            resultTeamId: resultTeamId,
            fieldPosition: field.map { $0.ball / 100 },
            drivingRight: isAway,
            field: field
        )
    }

    /// "4 plays, 57 yds". ESPN's own line carries the elapsed time too,
    /// which the card leaves to the Plays tab.
    static func driveLine(_ drive: Drive) -> String? {
        guard let plays = drive.offensivePlays, let yards = drive.yards else { return drive.summary }
        return "\(plays) \(plays == 1 ? "play" : "plays"), \(yards) \(abs(yards) == 1 ? "yd" : "yds")"
    }

    /// The name a scoring drive goes by. A touchdown outranks the extra
    /// point that follows it, which is the last scoring play on the drive
    /// but not what anyone calls it.
    static func resultName(of scoring: [Play]) -> String? {
        let types = scoring.compactMap { $0.typeText?.lowercased() }
        if types.contains(where: { $0.contains("touchdown") }) { return "Touchdown" }
        if types.contains(where: { $0.contains("field goal") }) { return "Field Goal" }
        if types.contains(where: { $0.contains("safety") }) { return "Safety" }
        return nil
    }
}
