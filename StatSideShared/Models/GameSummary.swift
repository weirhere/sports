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
}

/// A game's betting line, narrowed to the two numbers a fan picks games
/// by (Coard Miller, 2026-09-24): ESPN's headline line and the total. No
/// provider, no moneyline column, no bet links — the rest of `pickcenter`
/// stays iced (BACKLOG, "There, large, and deliberately not ours").
nonisolated struct GameLine: Hashable, Sendable {
    let details: String?
    let overUnder: Double?

    /// Nil when neither half survived, so an empty line has no row.
    init?(details: String?, overUnder: Double?) {
        let trimmed = details?.trimmingCharacters(in: .whitespaces)
        let details = trimmed?.isEmpty == false ? trimmed : nil
        guard details != nil || overUnder != nil else { return nil }
        self.details = details
        self.overUnder = overUnder
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
}

/// One play inside a drive: ESPN's play-by-play row, and the source of
/// the live situation strip (the current drive's last play knows the
/// down, the ball's spot, and how far it is from the end zone).
nonisolated struct Play: Identifiable, Hashable, Sendable {
    let id: String
    /// ESPN's own narration — "(12:16) Shotgun #15 F.Mendoza pass
    /// complete short right to #3 O.Cooper for 11 yards".
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

/// The Gamecast strip's content: who has the ball, on what down, where,
/// and what just happened. Derived entirely from the current drive's last
/// play — one verified shape rather than a second live-only payload.
nonisolated struct GameSituation: Hashable, Sendable {
    let possessionTeamId: String?
    /// "2nd & 4".
    let downDistanceText: String?
    /// "WSU 26" — the ball's spot.
    let possessionText: String?
    /// The drive so far: "1 play, 6 yards, 0:05".
    let driveSummary: String?
    /// ESPN's narration of the play that just ended.
    let lastPlayText: String?
    /// Where the ball sits, 0 at the away team's own goal line and 1 at
    /// the home team's. Nil when the payload gave no distance, which
    /// leaves the field bar off and the rest of the strip standing.
    let fieldPosition: Double?
    /// True when the offense is moving toward the home end zone — the
    /// away team has the ball, so the bar's arrow points right.
    let drivingRight: Bool
}

extension GameSummary {
    /// Nil unless a drive is in progress with a play on it. Everything
    /// here is optional inside ESPN's payload, so a half-filled situation
    /// renders the lines it has and drops the ones it doesn't.
    var situation: GameSituation? {
        guard let drive = currentDrive, let play = drive.plays.last else { return nil }
        let isAway = drive.teamId != nil && drive.teamId == away?.team.id
        return GameSituation(
            possessionTeamId: drive.teamId,
            downDistanceText: play.nextDownDistanceText,
            possessionText: play.possessionText,
            driveSummary: drive.summary,
            lastPlayText: play.text,
            fieldPosition: play.yardsToEndzone.map {
                // yardsToEndzone counts down toward the *defense's* end
                // zone, so which end of the bar that is depends on who
                // has the ball. Clamped: a payload can hand back a spot
                // past the goal line on a scoring play.
                let fromAwayGoal = isAway ? 100 - $0 : $0
                return min(max(Double(fromAwayGoal) / 100, 0), 1)
            },
            drivingRight: isAway
        )
    }
}
