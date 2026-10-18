import Foundation

// ESPN's JSON shapes, mirrored defensively. Every field is optional; numeric
// fields tolerate string/number drift. These types never leave the
// Networking layer — ESPNClient maps them to domain models.

/// Decodes an Int from an Int, a numeric String, or a Double.
nonisolated struct FlexibleInt: Decodable, Hashable, Sendable {
    let value: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let string = try? container.decode(String.self) {
            value = Int(string) ?? Double(string).map(Int.init)
        } else if let double = try? container.decode(Double.self) {
            value = Int(double)
        } else {
            value = nil
        }
    }
}

/// Decodes an array element-by-element, dropping elements that fail instead
/// of failing the whole array — one bad event never kills the screen.
nonisolated struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    private struct Blank: Decodable {
        init(from decoder: Decoder) throws {}
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                result.append(element)
            } else {
                _ = try? container.decode(Blank.self)
            }
        }
        elements = result
    }
}

// MARK: - Scoreboard

nonisolated struct ScoreboardDTO: Decodable {
    /// Lossy, like `events`: one league object we can't read must never
    /// cost the whole slate.
    let leagues: LossyArray<LeagueDTO>?
    let season: SeasonDTO?
    let week: WeekRefDTO?
    let events: LossyArray<EventDTO>?
}

nonisolated struct LeagueDTO: Decodable {
    /// ESPN ships two different calendars under one key, and which one you
    /// get depends on the league *and* the request.
    ///
    /// Football's is a list of labelled periods with week entries inside —
    /// what `weekSlots` reads. Basketball's and hockey's is a flat list of
    /// **ISO date strings**, one per game day (229 of them for a season),
    /// because `calendarType` there is "day" rather than "list". A single
    /// `dates=` request returns it; a date *range* returns an empty array,
    /// which is why this shape stayed hidden until a one-day fixture was
    /// captured.
    ///
    /// Lossy, so the string form decodes to no periods rather than
    /// throwing. It threw before, and because `leagues` was a plain array
    /// the throw took the entire scoreboard with it — every event of a
    /// single-day NBA or NHL request, lost to a field nothing reads for
    /// those leagues.
    let calendar: LossyArray<CalendarPeriodDTO>?

    /// "list" or "day" — the same split `calendar`'s doc comment already
    /// names, given its own key here because ESPN states it outright rather
    /// than leaving it to be inferred from the calendar's shape.
    let calendarType: String?
    /// The season's real bounds, ISO 8601 — present in every held fixture
    /// (all four leagues, current season). Whether a past season or a
    /// `dates=` day request still carries it is unprobed; this decodes
    /// defensively rather than assuming either way.
    let calendarStartDate: String?
    let calendarEndDate: String?
}

nonisolated struct CalendarPeriodDTO: Decodable {
    let label: String?
    let value: FlexibleInt?
    let startDate: String?
    let endDate: String?
    let entries: [CalendarEntryDTO]?
}

nonisolated struct CalendarEntryDTO: Decodable {
    let label: String?
    let alternateLabel: String?
    let detail: String?
    let value: FlexibleInt?
    let startDate: String?
    let endDate: String?
}

nonisolated struct SeasonDTO: Decodable {
    let type: Int?
    let year: Int?
}

nonisolated struct WeekRefDTO: Decodable {
    let number: Int?
}

nonisolated struct EventDTO: Decodable {
    let id: String?
    let date: String?
    let name: String?
    let shortName: String?
    let week: WeekRefDTO?
    let season: EventSeasonDTO?
    let status: StatusDTO?
    let competitions: [CompetitionDTO]?
}

nonisolated struct EventSeasonDTO: Decodable {
    /// ESPN's season year — the *end* year for the NBA and NHL.
    let year: Int?
    /// 2 = regular season, 3 = postseason.
    let type: Int?
}

nonisolated struct StatusDTO: Decodable {
    let clock: Double?
    let displayClock: String?
    let period: Int?
    let type: StatusTypeDTO?
    /// The NFL's flag that a kickoff is TBD *because of flex scheduling*,
    /// on the **competition's** status object, not the event's — the
    /// scoreboard and the team schedule both ship it there and nowhere
    /// else (verified against `nfl-scoreboard.json` and
    /// `nfl-team-schedule.json`; absent from the summary header's status,
    /// the only other place `StatusDTO` decodes). `CompetitionDTO.timeValid`
    /// already says a kickoff is TBD; this says why.
    let isTBDFlex: Bool?
}

nonisolated struct StatusTypeDTO: Decodable {
    let id: String?
    let name: String?
    let state: String?      // "pre" | "in" | "post"
    let completed: Bool?
    let detail: String?
    let shortDetail: String?
    /// "OT", "SO" — the NHL's shootout marker (`Final/SO`), cited by
    /// `PeriodLabel`'s own doc comment but undecoded until now. `PeriodLabel`
    /// still derives OT/SO from period arithmetic; drawing from this field
    /// instead is a separate change.
    let altDetail: String?
}

nonisolated struct CompetitionDTO: Decodable {
    let id: String?
    let date: String?
    // false = kickoff time unannounced; the date is a midnight *Eastern*
    // placeholder, which is the previous day west of ET — re-anchored by
    // `ESPNDate.parseKickoff` on the way into `Game`.
    let timeValid: Bool?
    let neutralSite: Bool?
    /// Whether the two teams belong to the same conference — ESPN's own
    /// answer to the question `Conference`'s hand-written division tables
    /// currently derive.
    let conferenceCompetition: Bool?
    let broadcast: String?
    let broadcasts: [BroadcastDTO]?
    /// The same slate of networks as `broadcasts`, geographically scoped:
    /// each entry names a market ("National", "Home", "Away") rather than
    /// flattening them into one string. BACKLOG.md.
    let geoBroadcasts: [GeoBroadcastDTO]?
    let competitors: [CompetitorDTO]?
    let situation: SituationDTO?
    /// Carries `isTBDFlex`; the event-level status above doesn't.
    let status: StatusDTO?
    /// Where the game is played. The scoreboard ships it on every
    /// competition, pre-game included, so this costs no request —
    /// `GameInfoDTO.venue` is the same shape read off `/summary` instead
    /// (BACKLOG.md E21). No capacity, same as that one.
    let venue: VenueDTO?
    /// "Bucked Up LA Bowl", "College Football Playoff Quarterfinal at the
    /// Allstate Sugar Bowl". The only thing distinguishing one postseason
    /// college-football game from another — ESPN files every bowl and every
    /// playoff round under one `seasontype=3` week (verified live
    /// 2026-09-06: 46 games, all week 1).
    let notes: [CompetitionNoteDTO]?
    /// The pre-game line, one entry per provider. Present on pre-game
    /// events and gone from finals (probed 2026-09-24, 0 of 76).
    let odds: LossyArray<OddsDTO>?
    /// How long a game is. Lean here — just `regulation.periods`, verified
    /// against the NFL, NBA and NHL scoreboard fixtures; the summary's own
    /// top-level `format` (`SummaryResponseDTO.format`) is the fuller
    /// version with `clock`/`overtime`/`suddenDeath`.
    let format: FormatDTO?
}

/// How long a game runs before it can end — `PeriodLabel`'s per-league
/// branches and `League.periodFormat`'s hand-written regulation counts are
/// exactly this, stated by the payload instead of guessed.
nonisolated struct FormatDTO: Decodable {
    let regulation: RegulationFormatDTO?
    let overtime: OvertimeFormatDTO?
    let suddenDeath: SuddenDeathFormatDTO?
}

nonisolated struct RegulationFormatDTO: Decodable {
    let periods: Int?
    let displayName: String?
    let slug: String?
    let clock: Double?
}

nonisolated struct OvertimeFormatDTO: Decodable {
    let displayName: String?
    let slug: String?
    let clock: Double?
}

nonisolated struct SuddenDeathFormatDTO: Decodable {
    let periods: Int?
}

nonisolated struct OddsDTO: Decodable {
    let details: String?
    let overUnder: Double?
    let homeTeamOdds: TeamOddsDTO?
    let awayTeamOdds: TeamOddsDTO?
}

nonisolated struct TeamOddsDTO: Decodable {
    let favorite: Bool?
}

nonisolated struct CompetitionNoteDTO: Decodable {
    let headline: String?
}

nonisolated struct BroadcastDTO: Decodable {
    let market: String?
    let names: [String]?
}

/// `geoBroadcasts[]`'s own entry shape — also the summary header's
/// `broadcasts[]`, which carries the identical nesting plus `isNational`.
nonisolated struct GeoBroadcastDTO: Decodable {
    let type: GeoBroadcastTypeDTO?
    let market: GeoBroadcastMarketDTO?
    let media: GeoBroadcastMediaDTO?
    /// Only the summary header's copy ships this directly; the
    /// scoreboard's `geoBroadcasts` doesn't, so the mapper derives it from
    /// `market.type` when this is nil.
    let isNational: Bool?
}

nonisolated struct GeoBroadcastTypeDTO: Decodable {
    /// "TV", "Radio", "Streaming", "Subscription Package".
    let shortName: String?
}

nonisolated struct GeoBroadcastMarketDTO: Decodable {
    /// "National", "Home", "Away".
    let type: String?
}

nonisolated struct GeoBroadcastMediaDTO: Decodable {
    let shortName: String?
    let logo: String?
    let darkLogo: String?
}

nonisolated struct SituationDTO: Decodable {
    let possession: String?         // team id with the ball
    let downDistanceText: String?
    let possessionText: String?
}

nonisolated struct CompetitorDTO: Decodable {
    let id: String?
    let homeAway: String?
    let score: FlexibleInt?
    let winner: Bool?
    let curatedRank: CuratedRankDTO?
    let records: [RecordDTO]?
    let team: TeamDTO?
}

nonisolated struct CuratedRankDTO: Decodable {
    let current: FlexibleInt?
}

nonisolated struct RecordDTO: Decodable {
    let name: String?
    let abbreviation: String?
    let type: String?
    let summary: String?
}

nonisolated struct TeamDTO: Decodable {
    let id: String?
    let location: String?
    let name: String?
    let nickname: String?
    let abbreviation: String?
    let displayName: String?
    let shortDisplayName: String?
    let logo: String?
    let logos: [LogoDTO]?
    let conferenceId: FlexibleInt?
    /// The same number under another name, and the same shape the
    /// schedule endpoint's team object carries. The scoreboard sends
    /// `conferenceId`; the **summary header** and the **rankings** send
    /// `groups` and no `conferenceId` at all (verified 2026-09-21 against
    /// the fixtures: Indiana arrives as `groups: {id: "5"}` on a summary
    /// and `{id: "5", parent: {id: "80"}}` in the AP poll — the Big Ten
    /// under FBS, both times). Read as a fallback, so a team decoded from
    /// either one knows its conference instead of guessing nil.
    let groups: TeamGroupsDTO?
    /// ESPN's team colors as bare hex ("970310"). Only the Gamecast
    /// field's end zones read them (2026-09-27) — the one place the color
    /// budget lets a team's own color in besides its logo.
    let color: String?
    let alternateColor: String?
}

nonisolated struct LogoDTO: Decodable {
    let href: String?
}

// MARK: - Standings (the source of FBS conference membership)
// Verified 2026-07-20: /apis/v2/.../standings?group=80 returns 11 conference
// children with exact rosters; the /teams endpoint has no conference data.

nonisolated struct StandingsResponseDTO: Decodable {
    let name: String?
    let children: [StandingsGroupDTO]?
    let season: StandingsSeasonDTO?
}

/// The season a standings response says it is for.
///
/// Its `year` cannot be trusted to describe the *numbers*: probed live
/// 2026-09-08, ESPN's NBA standings stamp the upcoming 2026-27 season on
/// a table still full of 2025-26 results. `startDate` can — a season that
/// opens in three weeks has been played by nobody.
nonisolated struct StandingsSeasonDTO: Decodable {
    let year: Int?
    let startDate: String?
}

nonisolated struct StandingsGroupDTO: Decodable {
    let id: FlexibleInt?
    let name: String?
    let shortName: String?
    let standings: StandingsListDTO?
    /// Divisional payloads nest a level deeper: a conference carries no
    /// entries of its own and hangs its divisions here. College football
    /// did this in its divisional era (the 2019 AAC's East and West), and
    /// the NFL does it whenever `level=3` is asked for. Unread until now,
    /// which is why a divisional season rendered "Standings TBA".
    let children: [StandingsGroupDTO]?
}

nonisolated struct StandingsListDTO: Decodable {
    let entries: LossyArray<StandingsEntryDTO>?
}

nonisolated struct StandingsEntryDTO: Decodable {
    let team: TeamDTO?
    let stats: [StandingsStatDTO]?
}

// Each entry carries ~20 stats; `type` is the discriminator ("total",
// "vsconf", "streak", plus prefixed variants like "homerecord_wins" we
// deliberately ignore).
nonisolated struct StandingsStatDTO: Decodable {
    let name: String?
    let type: String?
    let summary: String?
    let displayValue: String?
    let value: Double?
}

// MARK: - Team schedule
// Quirks vs. the scoreboard shape: score is an object, record is an array
// under "record", status lives on the competition, broadcasts nest media.

nonisolated struct ScheduleResponseDTO: Decodable {
    // `season` is ESPN's current season; `requestedSeason` the one this
    // response actually contains (they differ during the nil-year
    // fallback and for any past-season request).
    let season: ScheduleSeasonDTO?
    let requestedSeason: ScheduleSeasonDTO?
    let team: ScheduleTeamDTO?
    let events: LossyArray<ScheduleEventDTO>?
    /// The week this team doesn't play. The NFL ships it at the top level
    /// (verified live 2026-09-05: Seattle's 2025 schedule says 8); college
    /// football omits it, since an open date there isn't a league-assigned
    /// bye anyone plans around.
    let byeWeek: FlexibleInt?
}

nonisolated struct ScheduleSeasonDTO: Decodable {
    let year: Int?
    let type: Int?
}

nonisolated struct ScheduleTeamDTO: Decodable {
    let id: String?
    let location: String?
    let name: String?
    let nickname: String?
    let abbreviation: String?
    let displayName: String?
    let shortDisplayName: String?
    let logo: String?
    let logos: [LogoDTO]?
    let recordSummary: String?
    let standingSummary: String?
    let groups: TeamGroupsDTO?
    /// The team's primary color — TeamPage's light-mode header. The
    /// schedule endpoint sends no `alternateColor` (probed 2026-09-27:
    /// Texas, Ohio State, the Celtics).
    let color: String?
}

/// The team's most specific group on the schedule endpoint — the conference
/// itself (`isConference: true`, parent = FBS 80) or, historically, a
/// division whose parent is the conference. One level of parent is all the
/// mapper needs, so the parent is its own one-field struct rather than a
/// recursive type.
nonisolated struct TeamGroupsDTO: Decodable {
    let id: FlexibleInt?
    let parent: TeamGroupsParentDTO?
    let isConference: Bool?
}

nonisolated struct TeamGroupsParentDTO: Decodable {
    let id: FlexibleInt?
}

nonisolated struct ScheduleEventDTO: Decodable {
    let id: String?
    let date: String?
    let timeValid: Bool?
    let name: String?
    let shortName: String?
    let week: WeekRefDTO?
    /// The schedule endpoint spells it `seasonType` on the event, where the
    /// scoreboard spells it `season.type` — same 1/2/3, different key. It
    /// is what separates a preseason game from a real one, and without it
    /// every schedule game looked like regular season.
    let seasonType: ScheduleSeasonTypeDTO?
    let competitions: [ScheduleCompetitionDTO]?
}

/// `id` is a *string* here and `type` the number — decode the number.
nonisolated struct ScheduleSeasonTypeDTO: Decodable {
    let type: Int?
}

nonisolated struct ScheduleCompetitionDTO: Decodable {
    let date: String?
    // false = kickoff time unannounced; the date is a midnight *Eastern*
    // placeholder, which is the previous day west of ET — re-anchored by
    // `ESPNDate.parseKickoff` on the way into `Game`.
    // The schedule endpoint carries it on the event too.
    let timeValid: Bool?
    let neutralSite: Bool?
    let status: StatusDTO?
    let competitors: [ScheduleCompetitorDTO]?
    let broadcasts: [ScheduleBroadcastDTO]?
    /// Where the game is played. The schedule endpoint ships it on every
    /// competition, played or not — name and address only, no `grass` and
    /// no venue `id`, so a team's home ground is nameable from the season
    /// it already fetched and its surface is not.
    let venue: VenueDTO?
    /// The announced crowd, on played games only. Averaging it across the
    /// season's home dates is the only crowd figure ESPN gives us that
    /// belongs to a *team* rather than to one game.
    let attendance: Int?
    /// What ESPN prints the game as: "SEC Championship", "Super Bowl LIX",
    /// "NBA Cup - Group Play". The scoreboard path has decoded this since
    /// the postseason bracket needed it; the schedule path never did, which
    /// is what left a team's own title games unnameable on its own page.
    ///
    /// **A headline is not a trophy.** Branded kickoffs and neutral-site
    /// regular games sit in this same field, so it is only ever read
    /// through `TrophyKind.from(headline:league:)`, which matches known
    /// wording and stays silent on everything else.
    let notes: [CompetitionNoteDTO]?
}

nonisolated struct ScheduleBroadcastDTO: Decodable {
    let media: ScheduleMediaDTO?
}

nonisolated struct ScheduleMediaDTO: Decodable {
    let shortName: String?
}

nonisolated struct ScheduleCompetitorDTO: Decodable {
    let homeAway: String?
    let winner: Bool?
    let score: ScheduleScoreDTO?
    let record: [ScheduleRecordDTO]?
    let curatedRank: CuratedRankDTO?
    let team: TeamDTO?
}

nonisolated struct ScheduleScoreDTO: Decodable {
    let value: Double?
    let displayValue: String?
}

nonisolated struct ScheduleRecordDTO: Decodable {
    let type: String?
    let displayValue: String?
    let summary: String?
}

// MARK: - Game summary

nonisolated struct SummaryResponseDTO: Decodable {
    let header: SummaryHeaderDTO?
    let boxscore: BoxscoreDTO?
    let scoringPlays: [ScoringPlayDTO]?
    let drives: DrivesDTO?
    /// The flat play feed. Football nests its plays inside drives and
    /// ships this too; basketball and hockey ship only this, because
    /// neither has a possession long enough to be worth grouping by.
    let plays: LossyArray<PlayDTO>?
    let leaders: LossyArray<SummaryTeamLeadersDTO>?
    /// ESPN's matchup predictor, before kickoff: each side's projected win
    /// chance as a string ("55.6"). College football carries it; the NBA
    /// and NHL fixtures don't.
    let predictor: PredictorDTO?
    /// The home side's win chance after every play, oldest first, 0...1.
    /// Football and basketball ship it; hockey ships none.
    let winprobability: LossyArray<WinProbabilityPointDTO>?
    let gameInfo: GameInfoDTO?
    /// The two competing teams' own standings tables, shipped inside the
    /// request the game page already makes (E21, 2026-09-21).
    let standings: SummaryStandingsDTO?
    /// Sportsbook lines, one entry per provider. Only the first entry's
    /// headline line and total are read (2026-09-24); the moneyline,
    /// per-team odds and bet links are deliberately left undecoded.
    let pickcenter: LossyArray<PickcenterDTO>?
    /// The game's own story: AP's preview before kickoff, its recap once
    /// the game is final, and nothing while it's live (probed 2026-09-27).
    /// The body rides along whole, so the game page's story card costs no
    /// request of its own (docs/news.md, N2 and N3).
    let article: NewsArticleDTO?
    /// The game's inactives, one entry per team — the NBA and NHL ship it;
    /// shaped nothing like `RosterInjuryDTO` (the roster's season-long
    /// list nested inside an athlete), this is the game-day list keyed by
    /// team with the athlete nested inside instead.
    let injuries: LossyArray<SummaryTeamInjuriesDTO>?
    /// The NHL's live lineup, one entry per team, by athlete id.
    let onIce: LossyArray<OnIceTeamDTO>?
    /// How long this game runs — top-level on `/summary`, not nested under
    /// `header.competitions[]` (verified across the NBA, NHL and football
    /// summary fixtures: `clock` in seconds, `overtime` and `suddenDeath`
    /// all live here, where the scoreboard's leaner `CompetitionDTO.format`
    /// carries only `regulation.periods`).
    let format: FormatDTO?
    /// This season's meetings between the two teams only — ESPN's nearest
    /// thing to a series resource and not enough of one; see
    /// `HeadToHeadFetch.swift`'s doc comment for why the H2H tab walks
    /// schedules instead. College football's summary ships none at all
    /// (confirmed on the held fixture); the NBA and NHL fixtures each
    /// carry one entry, `type: "season"` — the playoff shape is unprobed
    /// (BACKLOG.md E21).
    let seasonseries: LossyArray<SeasonSeriesDTO>?
}

nonisolated struct SeasonSeriesDTO: Decodable {
    let type: String?
    let summary: String?
    let completed: Bool?
    let totalCompetitions: Int?
    let seriesScore: String?
    let events: LossyArray<SeasonSeriesEventDTO>?
}

nonisolated struct SeasonSeriesEventDTO: Decodable {
    let id: String?
    let statusType: StatusTypeDTO?
}

nonisolated struct SummaryTeamInjuriesDTO: Decodable {
    let team: TeamDTO?
    let injuries: LossyArray<GameInjuryDTO>?
}

nonisolated struct GameInjuryDTO: Decodable {
    /// "Questionable", "Out", "Injured Reserve", "Day-To-Day".
    let status: String?
    let athlete: AthleteDTO?
    let type: InjuryTypeDTO?
    let details: InjuryDetailsDTO?
}

/// What the injury is, as far as ESPN says: `type` is the body part or
/// the ailment ("Neck", "Hamstring", "Illness"), `returnDate` a bare
/// `yyyy-MM-dd`. `location`, `side` and `detail` are mostly "Not
/// Specified" and stay undecoded.
nonisolated struct InjuryDetailsDTO: Decodable {
    let type: String?
    let returnDate: String?
}

nonisolated struct InjuryTypeDTO: Decodable {
    let description: String?
    let abbreviation: String?
}

nonisolated struct OnIceTeamDTO: Decodable {
    let teamId: String?
    let entries: LossyArray<OnIceEntryDTO>?
}

nonisolated struct OnIceEntryDTO: Decodable {
    let athleteid: String?
    let whereabouts: OnIceWhereaboutsDTO?
}

nonisolated struct OnIceWhereaboutsDTO: Decodable {
    let description: String?
}

nonisolated struct PickcenterDTO: Decodable {
    /// ESPN's own headline line: "IU -7.5" in football and basketball,
    /// the moneyline ("ANA -185") in hockey.
    let details: String?
    let overUnder: Double?
}

// MARK: - News
// One shape across three sources: the summary's `article`, a `/news` feed's
// `articles[]`, and the content API's `headlines[]`. Each carries a subset —
// the feed has no `story`, no `source` and no `gameId` — so every field is
// optional and the mapper names what's missing rather than guessing.
//
// `images`, `video`, `links.web` and the reactions and comments flags are
// deliberately not decoded: the reader is text-only (N8) and never sends
// anyone to espn.com (N4).

nonisolated struct NewsArticleDTO: Decodable {
    let id: FlexibleInt?
    let type: String?
    let headline: String?
    let description: String?
    let byline: String?
    let source: String?
    let published: String?
    let story: String?
    let gameId: FlexibleInt?
    let categories: LossyArray<NewsCategoryDTO>?
    let links: NewsLinksDTO?
    let images: LossyArray<NewsImageDTO>?
}

/// One of a story's photos. `header` is the story's own lead photo; `Media`
/// is a video's still.
nonisolated struct NewsImageDTO: Decodable {
    let type: String?
    let url: String?
}

nonisolated struct NewsCategoryDTO: Decodable {
    let type: String?
    let description: String?
    let teamId: FlexibleInt?
    let eventId: FlexibleInt?
}

nonisolated struct NewsLinksDTO: Decodable {
    let api: NewsAPILinksDTO?
}

nonisolated struct NewsAPILinksDTO: Decodable {
    let selfLink: NewsHrefDTO?

    enum CodingKeys: String, CodingKey {
        case selfLink = "self"
    }
}

nonisolated struct NewsHrefDTO: Decodable {
    let href: String?
}

/// `/news?team=`: a team's feed, headlines only.
nonisolated struct NewsFeedDTO: Decodable {
    let articles: LossyArray<NewsArticleDTO>?
}

/// The athlete overview's `news` block: ESPN's own list of a player's
/// stories, the one per-player source it publishes (`/news?athlete=` is
/// ignored). Only `news` is decoded; the stats and game log it also
/// carries come from their own endpoints.
nonisolated struct AthleteOverviewNewsDTO: Decodable {
    let news: LossyArray<NewsArticleDTO>?
}

/// The content API's single story, the body a feed item opens to.
nonisolated struct NewsHeadlinesDTO: Decodable {
    let headlines: LossyArray<NewsArticleDTO>?
}

// MARK: - Standings, the summary's own copy
// A thinner thing than `StandingsResponseDTO`'s: the entry's `team` is a
// display *string* with the id beside it, and `logo` is an array rather
// than a `logos` one. The stats are the same `StandingsStatDTO` shape, so
// the entry mapping is shared with the standings endpoint's.
//
// `isSameConference` is deliberately NOT decoded. It reads `true` on
// Miami (ACC) vs Indiana (Big Ten) — it compares `conferenceHeader`,
// which is "FBS" on both, so in college football it answers a division
// question, not a conference one. `MatchupStandings` keeps deriving the
// fact by hand from the two teams' tables, which is the only reading
// that can't be wrong.

nonisolated struct SummaryStandingsDTO: Decodable {
    let groups: [SummaryStandingsGroupDTO]?
}

nonisolated struct SummaryStandingsGroupDTO: Decodable {
    /// "2026 Atlantic Coast Conference Standings" — a sentence, carrying
    /// the season. The short form is what a caption wants.
    let header: String?
    let divisionHeader: String?
    let shortDivisionHeader: String?
    let standings: SummaryStandingsListDTO?
}

nonisolated struct SummaryStandingsListDTO: Decodable {
    let entries: LossyArray<SummaryStandingsEntryDTO>?
}

nonisolated struct SummaryStandingsEntryDTO: Decodable {
    let id: String?
    /// ESPN's display name for the team ("Boston College"), where the
    /// standings endpoint sends a whole team object.
    let team: String?
    let logo: [LogoHrefDTO]?
    let stats: [StandingsStatDTO]?
}

nonisolated struct LogoHrefDTO: Decodable {
    let href: String?
    let rel: [String]?
}

nonisolated struct DrivesDTO: Decodable {
    let previous: LossyArray<DriveDTO>?
    /// The possession in progress. ESPN ships it on live games only, in
    /// the same shape as a previous drive, and drops it once the game
    /// goes final — which is what retires the situation strip.
    let current: DriveDTO?
}

nonisolated struct DriveDTO: Decodable {
    let id: String?
    let description: String?     // "5 plays, 20 yards, 2:39"
    /// The same line's parts, which the current drive card lays out as
    /// its own "4 plays, 57 yds" column. Flexible, since a drive that
    /// failed to decode over one mistyped number would drop off the log.
    let offensivePlays: FlexibleInt?
    let yards: FlexibleInt?
    /// "2:39" — the Plays tab's third drive column.
    let timeElapsed: ClockRefDTO?
    let displayResult: String?   // "Punt", not the ALL-CAPS `result`
    /// "PUNT", "TD" — the same word `result` sends, not an abbreviation of
    /// `displayResult`. A compact label the Plays tab's drive row could
    /// use where "Punt" is the one spelled-out word.
    let shortDisplayResult: String?
    let isScore: Bool?
    let team: TeamDTO?
    let start: DriveEndpointDTO?
    let plays: LossyArray<PlayDTO>?
}

/// One play-by-play row. `start` describes the down the play began on and
/// `end` the down it left behind — the live strip wants `end` (what
/// happens next), the play list wants `start` (what this play faced).
nonisolated struct PlayDTO: Decodable {
    let id: String?
    let text: String?
    let type: PlayTypeDTO?
    let period: PeriodRefDTO?
    let clock: ClockRefDTO?
    let scoringPlay: Bool?
    let awayScore: Int?
    let homeScore: Int?
    let start: PlayEndpointDTO?
    let end: PlayEndpointDTO?
    /// Who made the play. Football reads the side off the drive it sits
    /// in; a flat feed has no drive, and a goals card with no mark beside
    /// the row can't say whose goal it was.
    let team: TeamRefDTO?
    /// Where a basketball or hockey play happened, in feet — the Gamecast
    /// shot map's only input (2026-09-27). Basketball folds every shot onto
    /// one half court (x across, y out from the baseline); hockey is the
    /// whole rink from center ice. A play with no spot ships
    /// `-214748340`, which the shot map drops.
    let coordinate: PlayCoordinateDTO?
    let shootingPlay: Bool?
    /// Hockey's manpower on the play: "even-strength", "power-play",
    /// "short-handed", "empty-net" — from the play's team's side.
    let strength: PlayTypeDTO?
    /// Football's own flags: whether the ball changed hands on this play
    /// and whether it was a penalty. `priority` is ESPN's key-play mark —
    /// every sampled instance was a scoring play, but nothing guarantees
    /// that holds live.
    let isTurnover: Bool?
    let isPenalty: Bool?
    let priority: Bool?
    /// Yards gained, as its own number rather than parsed out of `text`.
    /// Flexible since a stat yardage is as prone to arriving as a string
    /// as any other ESPN number.
    let statYardage: FlexibleInt?
    /// The flat feed's compact label — "Missed FG", "Turnover" — where
    /// `text` is a full sentence. Basketball and hockey ship it; football's
    /// drive-nested plays don't.
    let shortDescription: String?
    /// Points or goals this play was worth: the NHL's 1, the NBA's 2 or 3,
    /// 0 on anything that didn't score. Separate from `scoringPlay` because
    /// a basketball and-one is one scoring play worth 3.
    let scoreValue: Int?
    /// Who was involved, by ESPN's own word for their role — hockey's
    /// `scorer`/`assister`/`saver`/`face-off-winner`, basketball's bare
    /// athlete ids with no role at all (every sampled jump ball and shot
    /// carried none). Football's drive-nested plays don't ship this; the
    /// flat feed does.
    let participants: LossyArray<PlayParticipantDTO>?
}

nonisolated struct PlayParticipantDTO: Decodable {
    let athlete: AthleteDTO?
    let type: String?
    /// The scorer's and the assister's own season tallies, stamped on the
    /// play that moved them — not a running total anywhere else in the
    /// payload. Mutually exclusive per sample: a `scorer` carries this,
    /// an `assister` carries `ytdAssists` instead.
    let ytdGoals: Int?
    let ytdAssists: Int?
}

nonisolated struct PlayCoordinateDTO: Decodable {
    let x: Double?
    let y: Double?
}

nonisolated struct TeamRefDTO: Decodable {
    let id: String?
}

nonisolated struct PlayEndpointDTO: Decodable {
    let downDistanceText: String?       // "1st & 10 at IU 5"
    let shortDownDistanceText: String?  // "1st & 10"
    let possessionText: String?         // "MIA 28"
    let yardsToEndzone: Int?
    /// Yards to a first down from this spot — the field's line to gain.
    let distance: FlexibleInt?
    /// Whose ball it was at this end of the play. A kickoff starts with
    /// the kicking team and ends with the receiver, which is how the
    /// mapper tells a snap from a change of possession.
    let team: TeamRefDTO?
}

nonisolated struct DriveEndpointDTO: Decodable {
    let period: PeriodRefDTO?
    let text: String?
}

nonisolated struct SummaryHeaderDTO: Decodable {
    let competitions: [HeaderCompetitionDTO]?
    /// The game's own billing — "College Football Playoff National
    /// Championship Presented by AT&T" — distinct from `notes[].headline`
    /// on the scoreboard's `CompetitionDTO`, which is the same kind of fact
    /// in a different response.
    let gameNote: String?
}

nonisolated struct HeaderCompetitionDTO: Decodable {
    let date: String?
    let status: StatusDTO?
    let competitors: [HeaderCompetitorDTO]?
    let conferenceCompetition: Bool?
    /// Same shape as the scoreboard's `geoBroadcasts`, under the summary's
    /// own key — each entry also ships `isNational` directly.
    let broadcasts: [GeoBroadcastDTO]?
}

nonisolated struct HeaderCompetitorDTO: Decodable {
    let homeAway: String?
    let winner: Bool?
    let score: FlexibleInt?
    let rank: FlexibleInt?
    let linescores: [LinescoreDTO]?
    let record: [ScheduleRecordDTO]?
    let team: TeamDTO?
}

nonisolated struct LinescoreDTO: Decodable {
    let displayValue: String?
}

nonisolated struct BoxscoreDTO: Decodable {
    let teams: [BoxscoreTeamDTO]?
    let players: [BoxscorePlayersDTO]?
}

nonisolated struct BoxscorePlayersDTO: Decodable {
    let team: TeamDTO?
    let statistics: [BoxscorePlayerGroupDTO]?
}

nonisolated struct BoxscorePlayerGroupDTO: Decodable {
    let name: String?       // "passing"
    let text: String?       // "Miami Passing" — team name prefixed
    let labels: [String]?   // the column headers, live-vs-final variable
    /// Plain-English column meanings ("Yards Per Pass Attempt" beside
    /// "AVG"), positionally paired with `labels`.
    let descriptions: [String]?
    let totals: [String]?
    let athletes: LossyArray<BoxscoreAthleteDTO>?
}

nonisolated struct BoxscoreAthleteDTO: Decodable {
    let athlete: AthleteDTO?
    /// Positionally paired with the group's `labels`.
    let stats: [String]?
    /// Basketball's lineup flags, on the row rather than the athlete
    /// (probed 2026-10-18 against `nba-summary.json`: 10 starters, 7
    /// `didNotPlay` with a `reason` of "COACH'S DECISION"). Football and
    /// hockey ship none of these — football's starters come off the core
    /// API's game-day roster instead (`CompetitorRosterDTO`).
    let starter: Bool?
    let didNotPlay: Bool?
    let reason: String?
    let active: Bool?
}

nonisolated struct BoxscoreTeamDTO: Decodable {
    let team: TeamDTO?
    let homeAway: String?
    let statistics: [BoxscoreStatDTO]?
}

nonisolated struct BoxscoreStatDTO: Decodable {
    let name: String?
    let label: String?
    let displayValue: String?
}

nonisolated struct ScoringPlayDTO: Decodable {
    let id: String?
    let period: PeriodRefDTO?
    let clock: ClockRefDTO?
    let text: String?
    let awayScore: Int?
    let homeScore: Int?
    let team: TeamDTO?
    let type: PlayTypeDTO?
}

nonisolated struct PeriodRefDTO: Decodable {
    let number: Int?
}

nonisolated struct ClockRefDTO: Decodable {
    let displayValue: String?
}

nonisolated struct PlayTypeDTO: Decodable {
    let text: String?
    let abbreviation: String?
}

nonisolated struct SummaryTeamLeadersDTO: Decodable {
    let team: TeamDTO?
    let leaders: [LeaderCategoryDTO]?
}

nonisolated struct LeaderCategoryDTO: Decodable {
    let name: String?
    let displayName: String?
    let leaders: [LeaderEntryDTO]?
}

nonisolated struct LeaderEntryDTO: Decodable {
    let displayValue: String?
    let athlete: AthleteDTO?
}

nonisolated struct AthleteDTO: Decodable {
    let id: String?
    let displayName: String?
    let fullName: String?
    let shortName: String?
    let jersey: String?
    let headshot: LogoDTO?
    /// The NBA and NHL box scores and every league's game-day injury list
    /// carry the athlete's position; football's box score does not.
    let position: RosterPositionDTO?
    /// The NHL box score's healthy scratch, on the athlete object.
    let scratched: Bool?
}

nonisolated struct PredictorDTO: Decodable {
    let homeTeam: PredictorTeamDTO?
    let awayTeam: PredictorTeamDTO?
}

nonisolated struct PredictorTeamDTO: Decodable {
    let gameProjection: FlexibleDouble?
}

/// A number ESPN sends as a string on some payloads and a number on others.
nonisolated struct FlexibleDouble: Decodable, Hashable, Sendable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = Double(string)
        } else {
            value = nil
        }
    }
}

nonisolated struct WinProbabilityPointDTO: Decodable {
    let homeWinPercentage: Double?
}

nonisolated struct GameInfoDTO: Decodable {
    let venue: VenueDTO?
    let attendance: Int?
    let weather: WeatherDTO?
}

nonisolated struct VenueDTO: Decodable {
    /// The core API's key for the venue — the site API's own venue object
    /// carries no capacity (verified across both leagues' captured
    /// summary and scoreboard payloads), so the id is how the number gets
    /// fetched.
    let id: String?
    let fullName: String?
    let address: VenueAddressDTO?
    let capacity: Int?
    let grass: Bool?
    /// Whether the venue is a dome, rather than whether it has one today
    /// — the scoreboard ships it on every competition, played or not
    /// (BACKLOG.md E21). The weather row next to this one reads it as the
    /// gate for "why a dome shows nothing rather than a forecast".
    let indoor: Bool?
}

nonisolated struct VenueAddressDTO: Decodable {
    let city: String?
    let state: String?
}

nonisolated struct WeatherDTO: Decodable {
    let displayValue: String?
    let temperature: Double?
}

// MARK: - Rankings

nonisolated struct RankingsResponseDTO: Decodable {
    let rankings: LossyArray<RankingDTO>?
}

nonisolated struct RankingDTO: Decodable {
    let id: String?
    let name: String?
    let shortName: String?
    let type: String?
    let headline: String?
    let shortHeadline: String?
    let ranks: LossyArray<RankDTO>?
    /// Teams receiving votes outside the top 25.
    let others: LossyArray<RankDTO>?
    /// Teams ranked last week and not this one.
    let droppedOut: LossyArray<RankDTO>?
    let occurrence: OccurrenceDTO?
}

/// This edition's week, named by ESPN itself ("Week 4", "Final Rankings").
nonisolated struct OccurrenceDTO: Decodable {
    let displayValue: String?
}

// MARK: - Historical rankings (sports.core.api)
//
// A second shape for the same idea. The core API is the only ESPN surface
// with a season/week axis for rankings, and it pays for that by shipping
// everything as a `$ref`: a rank names its team by URL, not inline.

/// A core-API collection page. Only `count` is read — the app addresses
/// the documents it wants by id rather than walking the refs.
nonisolated struct CoreCollectionDTO: Decodable {
    let count: Int?
}

/// A `{"$ref": "…"}` pointer.
nonisolated struct CoreRefDTO: Decodable {
    let ref: String?

    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
    }

    /// The team id out of a `…/seasons/2019/teams/99?lang=en` ref.
    var teamId: String? { Self.id(in: ref, after: "/teams/") }

    /// The athlete id out of a `…/seasons/2026/athletes/4430841?lang=en` ref.
    var athleteId: String? { Self.id(in: ref, after: "/athletes/") }

    /// The position id out of a `…/positions/30?lang=en` ref — resolved
    /// against `ESPNPositions`, never fetched.
    var positionId: String? { Self.id(in: ref, after: "/positions/") }

    /// The numeric id that follows `segment` in a ref, or nil.
    static func id(in ref: String?, after segment: String) -> String? {
        guard let ref, let tail = ref.components(separatedBy: segment).last,
              tail != ref else { return nil }
        let id = tail.prefix { $0.isNumber }
        return id.isEmpty ? nil : String(id)
    }
}

/// A poll's season index — `seasons/{year}/rankings/{id}` — whose
/// `rankings` are one ref per week that poll was published, preseason to
/// final. The only document that says which weeks exist before they're
/// fetched.
nonisolated struct CoreRankingIndexDTO: Decodable {
    let rankings: LossyArray<CoreRefDTO>?
}

nonisolated struct CoreRankingDTO: Decodable {
    let id: String?
    let name: String?
    let shortName: String?
    let type: String?
    let headline: String?
    let shortHeadline: String?
    let ranks: LossyArray<CoreRankDTO>?
}

nonisolated struct CoreRankDTO: Decodable {
    let current: Int?
    let previous: Int?
    let points: Double?
    let firstPlaceVotes: Int?
    let record: CoreRecordDTO?
    let team: CoreRefDTO?
}

nonisolated struct CoreRecordDTO: Decodable {
    let summary: String?
}

// MARK: - Team directory
// The one request that names every team ESPN knows (760 of them, FCS
// included). It carries no conference data — that's what the standings
// endpoint is for — but names, abbreviations and logos are all the
// ref-shaped rankings need.

nonisolated struct TeamsResponseDTO: Decodable {
    let sports: [SportDTO]?

    nonisolated struct SportDTO: Decodable {
        let leagues: [LeagueDTO]?
    }

    nonisolated struct LeagueDTO: Decodable {
        let teams: [Entry]?
    }

    nonisolated struct Entry: Decodable {
        let team: TeamDTO?
    }
}

/// `/teams/{id}`: one team, colors included. Read only for the color —
/// a player's or coach's header paints in their team's (2026-10-03), and
/// a page that wasn't opened from the team's own page has no other
/// payload carrying it.
nonisolated struct TeamDetailResponseDTO: Decodable {
    let team: TeamDTO?
}

nonisolated struct RankDTO: Decodable {
    let current: Int?
    let previous: Int?
    let points: Double?
    let firstPlaceVotes: Int?
    let trend: String?
    let recordSummary: String?
    let team: TeamDTO?
}

// MARK: - Roster
// Verified live 2026-09-10 on all four leagues. Two things the shapes here
// defend against:
//
//   1. `athletes` arrives in **two forms**. The NFL, college football and the
//      NHL ship `[{position, items: [athlete]}]`; the NBA ships a flat
//      `[athlete]` with no grouping whatsoever. A decoder written for one
//      silently returns nothing for the other.
//   2. The endpoint takes no season. `?season=2019` answers 200 and echoes the
//      season back with zero athletes, so there is nothing to decode a year
//      from and nothing to ask a past season for.

nonisolated struct RosterResponseDTO: Decodable {
    /// Lossy, and the element itself is either-shaped: one unreadable group
    /// or player must never take the roster with it.
    let athletes: LossyArray<RosterEntryDTO>?
    let coach: LossyArray<RosterCoachDTO>?
}

/// One element of `athletes` — a position group, or (the NBA) a player
/// standing on its own.
nonisolated enum RosterEntryDTO: Decodable {
    case group(RosterGroupDTO)
    case player(RosterAthleteDTO)

    init(from decoder: Decoder) throws {
        // `items` is the discriminator: a group always carries one, and an
        // athlete object never does. The `try?` matters — the two shapes
        // disagree about the *type* under `position` (a group's is a string,
        // a player's an object), so an athlete fails the group decode
        // outright rather than merely coming back itemless.
        if let group = try? RosterGroupDTO(from: decoder), group.items != nil {
            self = .group(group)
        } else {
            // Neither shape: throws, and `LossyArray` drops the element.
            self = .player(try RosterAthleteDTO(from: decoder))
        }
    }
}

nonisolated struct RosterGroupDTO: Decodable {
    /// The group's own name. Lowercase codes in football ("offense",
    /// "specialTeam"); already display-ready in hockey ("Centers").
    let position: String?
    let items: LossyArray<RosterAthleteDTO>?
}

nonisolated struct RosterAthleteDTO: Decodable {
    let id: String?
    let displayName: String?
    let fullName: String?
    let jersey: String?
    /// ESPN pre-formats both with their units — "6' 2"", "225 lbs" — so the
    /// app never has to guess whether a league is metric.
    let displayHeight: String?
    let displayWeight: String?
    let age: Int?
    let headshot: LogoDTO?
    let position: RosterPositionDTO?
    /// College football's class year lives here ("Freshman" / "FR"). The pro
    /// leagues ship only `years`, which is seasons played, not a class.
    let experience: RosterExperienceDTO?
    let injuries: LossyArray<RosterInjuryDTO>?
}

nonisolated struct RosterPositionDTO: Decodable {
    let name: String?
    let displayName: String?
    let abbreviation: String?
}

nonisolated struct RosterExperienceDTO: Decodable {
    let years: Int?
    let displayValue: String?
    let abbreviation: String?
}

nonisolated struct RosterInjuryDTO: Decodable {
    let status: String?
}

nonisolated struct RosterCoachDTO: Decodable {
    /// Joins to the core API's `coaches/{id}` (E27, 2026-09-27).
    let id: FlexibleID?
    let firstName: String?
    let lastName: String?
}

// MARK: - Game-day roster and depth charts (the core API)
// Probed live 2026-10-18 across all four leagues. Two resources, both
// ref-shaped like the rest of `sports.core.api.espn.com`:
//
//   1. `events/{e}/competitions/{e}/competitors/{team}/roster` — who dressed
//      for *this* game. Football (NFL and college) flags 22 `starter`s and,
//      in the NFL, the declared inactives as `didNotPlay`, from the moment
//      the lineup is set (an NFL game four hours out had all of it; a
//      college game a week out 404s, so the lineup is game-day there). The
//      NBA flags its five starters and its DNPs with a `reason`; the NHL
//      flags `scratched` and names no starters. Positions are `$ref`s
//      into `ESPNPositions`' table and names are the short form
//      ("E. Greene III"), so the roster is joined to the team's own
//      `/roster` for full names and photos.
//   2. `seasons/{y}/teams/{team}/depthcharts` — the NBA and NHL ship one
//      chart each (`pg`…`c`; `lw`, `c`, `rw`, `ld`, `rd`, `g`) with a
//      `rank` per athlete, which is the only pre-game "who starts" either
//      league publishes. The NFL ships three (base defense, special teams,
//      a three-receiver offense) and is not asked: its game-day roster
//      already names the starters. College football answers 400.

nonisolated struct CompetitorRosterDTO: Decodable {
    let entries: LossyArray<CompetitorRosterEntryDTO>?
}

nonisolated struct CompetitorRosterEntryDTO: Decodable {
    /// An integer in the payload.
    let playerId: FlexibleID?
    /// ESPN's short form — a last name, initialed where the team has two.
    let displayName: String?
    let jersey: String?
    let starter: Bool?
    let didNotPlay: Bool?
    /// Live only: on the field right now. False on every entry of a
    /// final or pre-game roster, so nothing reads it yet.
    let active: Bool?
    /// Basketball's "COACH'S DECISION" beside `didNotPlay`.
    let reason: String?
    /// Hockey's healthy scratch, with "SCRATCHED" beside it.
    let scratched: Bool?
    let scratchReason: String?
    let position: CoreRefDTO?
    /// Present only on an entry that recorded a stat — college football's
    /// only hint at who got on the field, since it declares no inactives.
    let statistics: CoreRefDTO?
}

nonisolated struct DepthChartsDTO: Decodable {
    let items: LossyArray<DepthChartDTO>?
}

nonisolated struct DepthChartDTO: Decodable {
    let id: String?
    let name: String?
    /// Keyed by lowercase abbreviation ("pg", "lw").
    let positions: [String: DepthChartPositionDTO]?
}

nonisolated struct DepthChartPositionDTO: Decodable {
    let position: DepthChartPositionInfoDTO?
    let athletes: LossyArray<DepthChartAthleteDTO>?
}

nonisolated struct DepthChartPositionInfoDTO: Decodable {
    let id: String?
    let abbreviation: String?
    let displayName: String?
}

nonisolated struct DepthChartAthleteDTO: Decodable {
    let athlete: CoreRefDTO?
    /// 1 is the starter, or the first line.
    let rank: Int?
}
