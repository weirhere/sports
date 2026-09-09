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
    /// 2 = regular season, 3 = postseason.
    let type: Int?
}

nonisolated struct StatusDTO: Decodable {
    let clock: Double?
    let displayClock: String?
    let period: Int?
    let type: StatusTypeDTO?
}

nonisolated struct StatusTypeDTO: Decodable {
    let id: String?
    let name: String?
    let state: String?      // "pre" | "in" | "post"
    let completed: Bool?
    let detail: String?
    let shortDetail: String?
}

nonisolated struct CompetitionDTO: Decodable {
    let id: String?
    let date: String?
    // false = kickoff time unannounced; the date is a midnight placeholder.
    let timeValid: Bool?
    let neutralSite: Bool?
    let broadcast: String?
    let broadcasts: [BroadcastDTO]?
    let competitors: [CompetitorDTO]?
    let situation: SituationDTO?
    /// "Bucked Up LA Bowl", "College Football Playoff Quarterfinal at the
    /// Allstate Sugar Bowl". The only thing distinguishing one postseason
    /// college-football game from another — ESPN files every bowl and every
    /// playoff round under one `seasontype=3` week (verified live
    /// 2026-09-06: 46 games, all week 1).
    let notes: [CompetitionNoteDTO]?
}

nonisolated struct CompetitionNoteDTO: Decodable {
    let headline: String?
}

nonisolated struct BroadcastDTO: Decodable {
    let market: String?
    let names: [String]?
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
    // false = kickoff time unannounced; the date is a midnight placeholder.
    // The schedule endpoint carries it on the event too.
    let timeValid: Bool?
    let neutralSite: Bool?
    let status: StatusDTO?
    let competitors: [ScheduleCompetitorDTO]?
    let broadcasts: [ScheduleBroadcastDTO]?
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
    let gameInfo: GameInfoDTO?
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
    let displayResult: String?   // "Punt", not the ALL-CAPS `result`
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
}

nonisolated struct TeamRefDTO: Decodable {
    let id: String?
}

nonisolated struct PlayEndpointDTO: Decodable {
    let downDistanceText: String?       // "1st & 10 at IU 5"
    let shortDownDistanceText: String?  // "1st & 10"
    let possessionText: String?         // "MIA 28"
    let yardsToEndzone: Int?
}

nonisolated struct DriveEndpointDTO: Decodable {
    let period: PeriodRefDTO?
    let text: String?
}

nonisolated struct SummaryHeaderDTO: Decodable {
    let competitions: [HeaderCompetitionDTO]?
}

nonisolated struct HeaderCompetitionDTO: Decodable {
    let date: String?
    let status: StatusDTO?
    let competitors: [HeaderCompetitorDTO]?
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
    let totals: [String]?
    let athletes: LossyArray<BoxscoreAthleteDTO>?
}

nonisolated struct BoxscoreAthleteDTO: Decodable {
    let athlete: AthleteDTO?
    /// Positionally paired with the group's `labels`.
    let stats: [String]?
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
    let shortName: String?
    let jersey: String?
    let headshot: LogoDTO?
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
}

/// The core API's venue resource, which is where `capacity` actually
/// lives. Only the one field is read.
nonisolated struct CoreVenueDTO: Decodable {
    let capacity: Int?
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
    var teamId: String? {
        guard let ref, let tail = ref.components(separatedBy: "/teams/").last else { return nil }
        let id = tail.prefix { $0.isNumber }
        return id.isEmpty ? nil : String(id)
    }
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

nonisolated struct RankDTO: Decodable {
    let current: Int?
    let previous: Int?
    let points: Double?
    let firstPlaceVotes: Int?
    let trend: String?
    let recordSummary: String?
    let team: TeamDTO?
}
