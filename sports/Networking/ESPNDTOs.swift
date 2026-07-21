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
