import Foundation

/// The leagues StatSide covers. Every ESPN request, every id namespace, and
/// every time-model rule hangs off this — ESPN's team and conference id
/// spaces are per-league and they collide hard (20 of 32 NFL team ids are
/// also real CFB teams: UCLA/Seahawks, Stanford/Chargers, USC/Jaguars;
/// conference id 8 is the SEC in college football and the AFC in the NFL;
/// group 9 is the NFL itself and the NHL itself).
///
/// The raw value is the persistence token. It is written into follow keys,
/// filter tokens, widget snapshots and deep links, so it must never change.
nonisolated enum League: String, Sendable, Codable, CaseIterable, Identifiable, Hashable {
    case collegeFootball = "cfb"
    case nfl
    case nba
    case nhl

    var id: String { rawValue }

    /// The sport path segment above the league's own. Football's two
    /// leagues share it; basketball and hockey do not, and all three base
    /// URLs `ESPNClient` builds are keyed on it.
    var sportSegment: String {
        switch self {
        case .collegeFootball, .nfl: "football"
        case .nba: "basketball"
        case .nhl: "hockey"
        }
    }

    /// The league path segment under the sport. Verified live 2026-09-08:
    /// scoreboard, standings, summary and team-schedule responses are
    /// shape-identical across all four.
    var pathSegment: String {
        switch self {
        case .collegeFootball: "college-football"
        case .nfl: "nfl"
        case .nba: "nba"
        case .nhl: "nhl"
        }
    }

    /// Row- and chip-width name.
    var shortName: String {
        switch self {
        case .collegeFootball: "CFB"
        case .nfl: "NFL"
        case .nba: "NBA"
        case .nhl: "NHL"
        }
    }

    var displayName: String {
        switch self {
        case .collegeFootball: "College Football"
        case .nfl: "NFL"
        case .nba: "NBA"
        case .nhl: "NHL"
        }
    }

    /// The league's own mark — the one ESPN's own scoreboard declares for
    /// it, in `leagues[].logos[]`.
    ///
    /// Three of the four sit in the `leagues/` bucket beside the team
    /// marks; college football's does not, which is what the 2026-09-05
    /// probe concluded from (`college-football`, `ncaa`, `ncaaf`, `cfb`,
    /// `ncaa_football` all 404 there). ESPN files it under `redesign/`
    /// instead, and ships it on every NCAAF scoreboard response — so all
    /// four leagues wear a real badge and the name-only header rule that
    /// hole forced stays retired (Andy, 2026-09-06).
    ///
    /// Static rather than decoded: the mark is a property of the league,
    /// not of a day's slate, so a header paints it on the first frame
    /// instead of after a fetch. A moved file degrades to the league's
    /// fallback glyph, exactly like an unknown conference id.
    ///
    /// None of them derives a dark twin — the NFL, NBA and NHL payloads do
    /// declare one, but a header badge rides `ConferenceLogo`'s light
    /// backing disc in dark mode, where a light-inked shield would vanish.
    var logoURL: URL? {
        switch self {
        case .nfl, .nba, .nhl:
            URL(string: "https://a.espncdn.com/i/teamlogos/leagues/500/\(pathSegment).png")
        case .collegeFootball:
            URL(string: "https://a.espncdn.com/redesign/assets/img/icons/ESPN-icon-football-college.png")
        }
    }

    /// The glyph a surface falls back to when a mark won't load or doesn't
    /// exist — an unknown conference id, a team with no logo. Per sport,
    /// because a basketball row wearing a football is a worse answer than
    /// no mark at all.
    ///
    /// The app's *own* chrome (the Scores tab icon, the wordmark) is a
    /// separate question and deliberately not read from here.
    var fallbackGlyph: String {
        switch self {
        case .collegeFootball, .nfl: "football.fill"
        case .nba: "basketball.fill"
        case .nhl: "hockey.puck.fill"
        }
    }

    /// How far back the season picker goes. College football floors at the
    /// CFP era; every other league keeps the same floor rather than
    /// offering decades nobody browses. For the NBA and NHL it means the
    /// 2014-15 season, since their years name the season they open.
    var seasonFloor: Int { 2014 }

    /// The calendar month a season's first game can fall in. College
    /// football opens in August (Week 0's last weekend); the NFL opens in
    /// late July with the Hall of Fame Game, which an August floor cut off
    /// the front of the season entirely (Andy, 2026-09-06). The NBA and
    /// NHL open in September with their preseasons — ESPN's own season
    /// objects start 2026-09-30 and 2025-09-20 (probed 2026-09-08).
    var seasonOpensIn: Int {
        switch self {
        case .collegeFootball: 8
        case .nfl: 7
        case .nba, .nhl: 9
        }
    }

    /// The last calendar month that still belongs to the *previous* season.
    /// College football ends in January (bowls/CFP); the NFL runs through
    /// the February Super Bowl; the NBA Finals and the Stanley Cup are
    /// decided in June.
    var seasonRollsOverAfter: Int {
        switch self {
        case .collegeFootball: 1
        case .nfl: 2
        case .nba, .nhl: 6
        }
    }

    /// Whether ESPN stamps a season with the calendar year it *ends* in.
    ///
    /// Football names a season by the year it opens: the 2026 season is
    /// August 2026 through February 2027. The NBA and NHL do the opposite
    /// — `season=2027` is October 2026 through June 2027, `displayName`
    /// "2026-27" (probed live 2026-09-08).
    ///
    /// Our own axis is always the opening year, everywhere: `SeasonYear`,
    /// `SeasonSpan`, the season picker, the per-year caches on
    /// ConferencePage and TeamPage. The translation happens at exactly one
    /// boundary — the query string — which is the same rule that keeps
    /// ESPN's shapes out of the rest of the app.
    var seasonYearIsEndYear: Bool {
        switch self {
        case .collegeFootball, .nfl: false
        case .nba, .nhl: true
        }
    }

    /// Our opening-year season → the value ESPN's `season=` wants.
    func espnSeason(for year: Int) -> Int { seasonYearIsEndYear ? year + 1 : year }

    /// The inverse, for reading a payload's `season.year` back onto our axis.
    func seasonYear(fromESPN year: Int) -> Int { seasonYearIsEndYear ? year - 1 : year }

    /// "2026" for football, "2026-27" for the NBA and NHL — ESPN's own
    /// `displayName` spelling. The two-digit pad matters at the decade
    /// boundary: 2009 is "2009-10", never "2009-1".
    func seasonLabel(_ year: Int) -> String {
        guard seasonYearIsEndYear else { return "\(year)" }
        return "\(year)-\(String(format: "%02d", (year + 1) % 100))"
    }

    /// Whether the day's slate breaks into one section per conference, or
    /// stands as one section for the league.
    ///
    /// Only college football is wide enough to need carving — 60 rows on a
    /// Saturday with no way in, and conferences are how fans already carve
    /// one up (Andy, 2026-09-06). A 16-game NFL Sunday, an 11-game NBA
    /// night and an 8-game NHL night are each the whole slate at a glance,
    /// and their divisions would be one or two rows a section.
    var slateSplitsByConference: Bool { self == .collegeFootball }

    /// How many seasons back a head-to-head series is assembled from.
    ///
    /// The window is really sized in *meetings* — ten is the list length
    /// that answers "who usually wins this" without becoming a scroll — and
    /// expressed in seasons, because seasons are what can be fetched. So
    /// the number follows how often two teams meet: football's leagues play
    /// each other once or twice a year, basketball's and hockey's two to
    /// four times.
    ///
    /// It is also the request bill. There is no head-to-head resource on
    /// ESPN, so a series costs two requests per season (the regular season
    /// and the postseason, which is where the rivalry games worth
    /// remembering are) — 20 for college football, 12 for the NFL, 6 for
    /// the others. Paid once, on an explicit tap, cached for the page's
    /// life and never polled; this constant is the dial if that is ever
    /// too much.
    var headToHeadSeasons: Int {
        switch self {
        case .collegeFootball: 10   // one meeting a year, so ten of them
        case .nfl: 6                // twice a year inside a division
        case .nba, .nhl: 3          // two to four times a year
        }
    }

    /// Whether the season has weeks worth grouping by. ESPN sends
    /// `week: null` on every NBA and NHL event and ships an empty
    /// `leagues[].calendar` for both (probed 2026-09-08), so a Weeks
    /// toggle there files a whole season under one unnamed card.
    var hasWeeks: Bool { !seasonYearIsEndYear }

    /// Whether this league's scoreboard and standings take college
    /// football's FBS/FCS `groups=` parameter. Replaces every
    /// `league == .nfl` in the client, which read as "the league that
    /// isn't college football" and stops being true at four.
    var hasCollegeDivisions: Bool { self == .collegeFootball }

    /// Whether the league ranks its teams. College football has the AP,
    /// Coaches and CFP polls; `/rankings` is a 404 for the other three and
    /// always will be (probed 2026-09-08).
    var hasPoll: Bool { self == .collegeFootball }

    /// Whether the surface underfoot is a fact about the game.
    ///
    /// Football is played on grass or turf and which one is a real
    /// difference. Basketball and hockey are played indoors on a floor and
    /// on ice — ESPN still ships `grass: false` for their arenas, which we
    /// were rendering as "Surface · Turf" on a hockey rink (Andy,
    /// 2026-09-09: "nba and nhl games aren't played on turf").
    var playsOnASurface: Bool { !seasonYearIsEndYear }

    /// What a league calls its scoring periods.
    ///
    /// ESPN says the same thing in `format.regulation.periods` on the
    /// summary (4/"Quarter" for the NBA, 3/"Period" for the NHL), but a
    /// live status line renders long before any summary lands, so this is
    /// a property of the league rather than of a payload.
    struct PeriodFormat: Sendable, Hashable {
        let regulationCount: Int
        /// "QUARTER" / "PERIOD", for the play-by-play's period headings.
        let longName: String
        /// "Q" / "P", for the status line's "Q3 5:24".
        let shortName: String
    }

    var periodFormat: PeriodFormat {
        switch self {
        case .collegeFootball, .nfl, .nba:
            PeriodFormat(regulationCount: 4, longName: "QUARTER", shortName: "Q")
        case .nhl:
            PeriodFormat(regulationCount: 3, longName: "PERIOD", shortName: "P")
        }
    }

    /// The leaders the Leaders card asks for, in the order it shows them.
    ///
    /// A preferred spelling, not a requirement: `ESPNMapper.leaders` falls
    /// back to whatever categories the payload actually named when none of
    /// these match, because a category we didn't think of beats an empty
    /// card. Football needs the list because ESPN ships many more than
    /// three there.
    var leaderCategories: [(name: String, label: String)] {
        switch self {
        case .collegeFootball, .nfl:
            [("passingYards", "Passing"), ("rushingYards", "Rushing"),
             ("receivingYards", "Receiving")]
        case .nba:
            [("points", "Points"), ("rebounds", "Rebounds"), ("assists", "Assists")]
        case .nhl:
            [("goals", "Goals"), ("assists", "Assists"), ("points", "Points")]
        }
    }

    /// The team stats the compare card lines up, in order. Names are
    /// ESPN's own `boxscore.teams[].statistics[].name`, read live
    /// 2026-09-08 — a name this league's payload doesn't carry drops its
    /// row rather than showing a blank one.
    var comparedStats: [(name: String, label: String)] {
        switch self {
        case .collegeFootball, .nfl:
            [("totalYards", "Total Yards"), ("netPassingYards", "Passing"),
             ("rushingYards", "Rushing"), ("thirdDownEff", "3rd Down"),
             ("turnovers", "Turnovers"), ("possessionTime", "Possession")]
        case .nba:
            [("fieldGoalPct", "FG%"), ("threePointFieldGoalPct", "3PT%"),
             ("totalRebounds", "Rebounds"), ("assists", "Assists"),
             ("turnovers", "Turnovers")]
        case .nhl:
            [("shotsTotal", "Shots"), ("powerPlayGoals", "Power Play"),
             ("faceoffPercent", "Faceoffs"), ("hits", "Hits"),
             ("penaltyMinutes", "Penalty Min")]
        }
    }

    /// What the Scoring slot on a game page is called, or nil for a league
    /// where it would be noise.
    ///
    /// Football scores a handful of times a game and each one is an event.
    /// Hockey's goals are the same shape, and ESPN flags them on the play
    /// feed. Basketball scores ~98 times a game: a chronological list of
    /// every bucket is the box score with worse formatting.
    var scoringCardTitle: String? {
        switch self {
        case .collegeFootball, .nfl: "Scoring"
        case .nhl: "Goals"
        case .nba: nil
        }
    }

    /// What a game starting is called. The kickoff reminder said "Kickoff
    /// soon" and "kicks off at" to everyone until basketball and hockey
    /// arrived; the request-id prefix `kickoff.` stays, because that is a
    /// persistence token rather than copy.
    var startNoun: String {
        switch self {
        case .collegeFootball, .nfl: "Kickoff"
        case .nba: "Tip-off"
        case .nhl: "Puck drop"
        }
    }

    var startVerbPhrase: String {
        switch self {
        case .collegeFootball, .nfl: "kicks off"
        case .nba: "tips off"
        case .nhl: "drops the puck"
        }
    }

    /// The path component ESPN files this league's team marks under, e.g.
    /// `/i/teamlogos/ncaa/500/130.png` vs `/i/teamlogos/nhl/500/tor.png`.
    /// All four publish a `500-dark` twin (NBA and NHL verified live
    /// 2026-09-08).
    var teamLogoPathComponent: String {
        switch self {
        case .collegeFootball: "ncaa"
        case .nfl: "nfl"
        case .nba: "nba"
        case .nhl: "nhl"
        }
    }

    /// Where conference marks live. College football has its own
    /// `ncaa_conf` bucket; the NFL files AFC/NFC beside the team marks
    /// (`nfl_conf` 404s — probed 2026-09-05). The NBA and NHL publish no
    /// conference marks at all under any bucket (`nba_conf` 404s — probed
    /// 2026-09-08), so their conference rows wear the league's own shield
    /// instead; see `Conference.logoURL(for:in:)`.
    var conferenceLogoPathComponent: String {
        switch self {
        case .collegeFootball: "ncaa_conf"
        case .nfl, .nba, .nhl: teamLogoPathComponent
        }
    }
}
/// A conference identified unambiguously across leagues.
///
/// A bare `Int` is the bug: ESPN group id 8 is the SEC in college football
/// and the American Football Conference in the NFL, and ids 1, 4, 12 collide
/// the same way. Anything persisted, navigated to, or looked up in a name
/// table carries the league with it.
nonisolated struct ConferenceID: Hashable, Codable, Sendable, Identifiable {
    let league: League
    let id: Int

    init(_ league: League, _ id: Int) {
        self.league = league
        self.id = id
    }

    /// Convenience for the common college-football case.
    static func cfb(_ id: Int) -> ConferenceID { ConferenceID(.collegeFootball, id) }
    static func nfl(_ id: Int) -> ConferenceID { ConferenceID(.nfl, id) }
    static func nba(_ id: Int) -> ConferenceID { ConferenceID(.nba, id) }
    static func nhl(_ id: Int) -> ConferenceID { ConferenceID(.nhl, id) }

    /// The persistence token: `"cfb-8"`. Round-trips through
    /// `init?(token:)`, which accepts a bare `"8"` as college football so
    /// values written before the league axis existed still read back.
    var token: String { "\(league.rawValue)-\(id)" }

    init?(token: String) {
        if let id = Int(token) {
            self = ConferenceID(.collegeFootball, id)
            return
        }
        let parts = token.split(separator: "-", maxSplits: 1)
        guard parts.count == 2,
              let league = League(rawValue: String(parts[0])),
              let id = Int(parts[1]) else { return nil }
        self = ConferenceID(league, id)
    }
}
