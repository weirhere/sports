import Foundation

// CollegeFootballData.com v2 response shapes, verified against their
// OpenAPI spec 2026-07-21. Same rule as the ESPN DTOs: every field is
// optional — a missing field degrades the row, never crashes the app.
// Top-level arrays decode through LossyArray so one bad element never
// kills a screen.

nonisolated struct CFBDCalendarWeekDTO: Decodable {
    let season: Int?
    let week: Int?
    let seasonType: String?
    let startDate: String?
    let endDate: String?
}

nonisolated struct CFBDGameDTO: Decodable {
    let id: Int?
    let season: Int?
    let week: Int?
    let seasonType: String?
    let startDate: String?
    let startTimeTBD: Bool?
    let completed: Bool?
    let venue: String?
    let attendance: Int?
    let notes: String?
    let homeId: Int?
    let homeTeam: String?
    let homeConference: String?
    let homeClassification: String?
    let homePoints: Int?
    let homeLineScores: [Double]?
    let awayId: Int?
    let awayTeam: String?
    let awayConference: String?
    let awayClassification: String?
    let awayPoints: Int?
    let awayLineScores: [Double]?
}

// MARK: - Live scoreboard (Tier 1+)

nonisolated struct CFBDScoreboardGameDTO: Decodable {
    let id: Int?
    let startDate: String?
    let tv: String?
    let status: String?      // "scheduled" | "in_progress" | "completed"
    let period: Int?
    let clock: String?
    let possession: String?  // "home" | "away"
    let homeTeam: CFBDScoreboardTeamDTO?
    let awayTeam: CFBDScoreboardTeamDTO?
}

nonisolated struct CFBDScoreboardTeamDTO: Decodable {
    let id: Int?
    let name: String?
    let conference: String?
    let points: Int?
}

// MARK: - Teams, records, rankings

nonisolated struct CFBDTeamDTO: Decodable {
    let id: Int?
    let school: String?
    let mascot: String?
    let abbreviation: String?
    let conference: String?
    let classification: String?
    let logos: [String]?
}

nonisolated struct CFBDTeamRecordsDTO: Decodable {
    let teamId: Int?
    let team: String?
    let total: CFBDRecordDTO?
    // Spec-verified only (v2 OpenAPI); needs a real-key check — a shape
    // miss degrades to nil conference records, never a crash.
    let conferenceGames: CFBDRecordDTO?
}

nonisolated struct CFBDRecordDTO: Decodable {
    let wins: Int?
    let losses: Int?
    let ties: Int?
}

nonisolated struct CFBDPollWeekDTO: Decodable {
    let season: Int?
    let seasonType: String?
    let week: Int?
    let polls: [CFBDPollDTO]?
}

nonisolated struct CFBDPollDTO: Decodable {
    let poll: String?
    let ranks: [CFBDPollRankDTO]?
}

nonisolated struct CFBDPollRankDTO: Decodable {
    let rank: Int?
    let teamId: Int?
    let school: String?
    let firstPlaceVotes: Int?
    let points: Double?   // domain carries poll points as Double
}

nonisolated struct CFBDGameMediaDTO: Decodable {
    let id: Int?
    let mediaType: String?
    let outlet: String?
}

// MARK: - Game detail

nonisolated struct CFBDDriveDTO: Decodable {
    let id: String?
    let gameId: Int?
    let offense: String?
    let scoring: Bool?
    let startPeriod: Int?
    let endPeriod: Int?
    let plays: Int?
    let yards: Int?
    let driveResult: String?
    let isHomeOffense: Bool?
    let endOffenseScore: Int?
    let endDefenseScore: Int?
}

nonisolated struct CFBDGameTeamStatsDTO: Decodable {
    let id: Int?
    let teams: [CFBDGameTeamStatsTeamDTO]?
}

nonisolated struct CFBDGameTeamStatsTeamDTO: Decodable {
    let teamId: Int?
    let team: String?
    let homeAway: String?
    let stats: [CFBDGameStatDTO]?
}

nonisolated struct CFBDGameStatDTO: Decodable {
    let category: String?
    let stat: String?
}

nonisolated struct CFBDGamePlayerStatsDTO: Decodable {
    let id: Int?
    let teams: [CFBDGamePlayerStatsTeamDTO]?
}

nonisolated struct CFBDGamePlayerStatsTeamDTO: Decodable {
    let team: String?
    let homeAway: String?
    let categories: [CFBDPlayerStatCategoryDTO]?
}

nonisolated struct CFBDPlayerStatCategoryDTO: Decodable {
    let name: String?
    let types: [CFBDPlayerStatTypeDTO]?
}

nonisolated struct CFBDPlayerStatTypeDTO: Decodable {
    let name: String?
    let athletes: [CFBDPlayerStatAthleteDTO]?
}

nonisolated struct CFBDPlayerStatAthleteDTO: Decodable {
    let id: String?
    let name: String?
    let stat: String?
}

// MARK: - Date parsing

nonisolated enum CFBDDate {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plain = ISO8601DateFormatter()

    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        return fractional.date(from: string) ?? plain.date(from: string)
    }
}
