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
    let leagues: [LeagueDTO]?
    let season: SeasonDTO?
    let week: WeekRefDTO?
    let events: LossyArray<EventDTO>?
}

nonisolated struct LeagueDTO: Decodable {
    let calendar: [CalendarPeriodDTO]?
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
    let status: StatusDTO?
    let competitions: [CompetitionDTO]?
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
}

nonisolated struct StandingsGroupDTO: Decodable {
    let id: FlexibleInt?
    let name: String?
    let shortName: String?
    let standings: StandingsListDTO?
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
    let competitions: [ScheduleCompetitionDTO]?
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
    let leaders: LossyArray<SummaryTeamLeadersDTO>?
    let gameInfo: GameInfoDTO?
}

nonisolated struct DrivesDTO: Decodable {
    let previous: LossyArray<DriveDTO>?
}

nonisolated struct DriveDTO: Decodable {
    let id: String?
    let description: String?     // "5 plays, 20 yards, 2:39"
    let displayResult: String?   // "Punt", not the ALL-CAPS `result`
    let isScore: Bool?
    let team: TeamDTO?
    let start: DriveEndpointDTO?
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
    let displayName: String?
    let shortName: String?
    let jersey: String?
}

nonisolated struct GameInfoDTO: Decodable {
    let venue: VenueDTO?
    let attendance: Int?
}

nonisolated struct VenueDTO: Decodable {
    let fullName: String?
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

nonisolated struct RankDTO: Decodable {
    let current: Int?
    let previous: Int?
    let points: Double?
    let firstPlaceVotes: Int?
    let trend: String?
    let recordSummary: String?
    let team: TeamDTO?
}
