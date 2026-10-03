import Foundation

/// A head coach's career, from ESPN's core API (E27, 2026-09-27).
///
/// **The only source there is.** The site API's roster names the coach and
/// an id and stops; the core API's `leagues/{league}/coaches/{id}` carries
/// the bio, ESPN's career records (Total, Regular Season, Post Season) and
/// one `coachSeasons` ref per season in the job, each naming that season's
/// team. So "where they coached before" is a walk of those refs.
///
/// **What it costs.** One request for the person, one per career record
/// (three at most), one for the alma mater, two per season (the season,
/// for its team; the season's record, whose path is derivable so both go
/// out together) and one per distinct team for its name and mark. Bowles
/// is ~26 requests; Carlisle's 24 NBA seasons ~55. All in parallel, on an
/// explicit tap, never polled — past seasons don't change.
///
/// Every failure degrades: a season whose team can't be read is dropped,
/// a record that 404s leaves its row out, and a person that won't decode
/// answers `nil` so the page keeps what the door brought.
nonisolated struct CoachClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// A team a coach worked for, as the core API names it — so a college
    /// program outside the directory's fetched divisions still reads as
    /// itself rather than as an id.
    struct TeamLabel: Sendable, Equatable {
        let name: String
        let abbreviation: String?
        let logoURL: URL?
    }

    struct Career: Sendable {
        let profile: CoachProfile
        let teams: [String: TeamLabel]
    }

    private func leagueBase(_ league: League) -> String {
        "https://sports.core.api.espn.com/v2/sports/\(league.sportSegment)/leagues/\(league.pathSegment)"
    }

    @concurrent
    func career(coachId: String, league: League) async -> Career? {
        let base = leagueBase(league)
        guard let person: CoachPersonDTO = await get(base + "/coaches/\(coachId)") else { return nil }

        async let records = careerRecords(person.careerRecords?.elements ?? [], league: league)
        async let college = collegeName(person.college?.ref)
        async let seasons = seasons(coachId: coachId, refs: person.coachSeasons?.elements ?? [],
                                    league: league)

        let loadedSeasons = await seasons
        let teams = await teamLabels(for: loadedSeasons, league: league)
        var profile = CoachMapper.profile(from: person)
        profile.records = await records
        profile.college = await college
        profile.seasons = loadedSeasons
        return Career(profile: profile, teams: teams)
    }

    // MARK: - Pieces

    private func careerRecords(_ refs: [CoreRefDTO], league: League) async -> [CoachRecord] {
        await withTaskGroup(of: CoachRecord?.self) { group in
            for ref in refs {
                group.addTask {
                    guard let dto: CoachRecordDTO = await self.get(ref.ref) else { return nil }
                    return CoachMapper.record(from: dto, league: league)
                }
            }
            var out: [CoachRecord] = []
            for await record in group { if let record { out.append(record) } }
            return CoachMapper.careerRecords(out)
        }
    }

    private func collegeName(_ ref: String?) async -> String? {
        guard let dto: CollegeDTO = await get(ref) else { return nil }
        return dto.name ?? dto.shortName
    }

    private func seasons(coachId: String, refs: [CoreRefDTO], league: League) async -> [CoachSeason] {
        let base = leagueBase(league)
        let years = Set(refs.compactMap { CoachMapper.seasonYear(inRef: $0.ref) })
        let rows = await withTaskGroup(of: [CoachSeason].self) { group in
            for espnYear in years {
                group.addTask {
                    async let season: CoachSeasonDTO? = get(base + "/seasons/\(espnYear)/coaches/\(coachId)")
                    async let record: CoachRecordDTO? =
                        get(base + "/seasons/\(espnYear)/types/2/coaches/\(coachId)/record")
                    let loaded = await season
                    let line = (await record).flatMap { CoachMapper.record(from: $0, league: league) }
                    return CoachMapper.seasons(from: loaded, espnYear: espnYear,
                                               record: line, league: league)
                }
            }
            var out: [CoachSeason] = []
            for await batch in group { out.append(contentsOf: batch) }
            return out
        }
        return CoachMapper.cleaned(rows)
    }

    private func teamLabels(for seasons: [CoachSeason], league: League) async -> [String: TeamLabel] {
        // The newest season each team appears in, so a rebrand reads as the
        // name the coach last worked under.
        var newest: [String: Int] = [:]
        for season in seasons where newest[season.teamId] == nil {
            newest[season.teamId] = season.year
        }
        let base = leagueBase(league)
        return await withTaskGroup(of: (String, TeamLabel?).self) { group in
            for (teamId, year) in newest {
                group.addTask {
                    let url = base + "/seasons/\(league.espnSeason(for: year))/teams/\(teamId)"
                    let dto: CoachTeamDTO? = await get(url)
                    guard let name = dto?.displayName ?? dto?.name else { return (teamId, nil) }
                    let logo = dto?.logos?.elements.first?.href.flatMap(URL.init(string:))
                    return (teamId, TeamLabel(name: name, abbreviation: dto?.abbreviation,
                                              logoURL: logo))
                }
            }
            var out: [String: TeamLabel] = [:]
            for await (id, label) in group { if let label { out[id] = label } }
            return out
        }
    }

    /// The core API's refs are `http://`, which App Transport Security
    /// refuses; the same document answers over https.
    private func get<T: Decodable>(_ string: String?) async -> T? {
        guard let string,
              let url = URL(string: string.replacingOccurrences(of: "http://", with: "https://")),
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode ?? 200 == 200
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Mapping

nonisolated enum CoachMapper {
    static func profile(from dto: CoachPersonDTO) -> CoachProfile {
        let name = [dto.firstName, dto.lastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let place = [dto.birthPlace?.city, dto.birthPlace?.state ?? dto.birthPlace?.country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return CoachProfile(name: name,
                            headshotURL: dto.headshot?.href.flatMap(URL.init(string:)),
                            dateOfBirth: dto.dateOfBirth.flatMap(birthDate),
                            birthPlace: place.isEmpty ? nil : place,
                            college: nil,
                            experience: dto.experience,
                            records: [],
                            seasons: [])
    }

    /// "1963-11-18T08:00Z". Only the calendar date is meant — the time is
    /// ESPN's midnight Pacific — so it's read as a date in UTC and nothing
    /// finer.
    static func birthDate(_ string: String) -> Date? {
        guard string.count >= 10 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(string.prefix(10)))
    }

    /// Which line this is, from ESPN's name ("Total", "Regular Season",
    /// "Post Season") with the ref's id (0, 2, 3) behind it.
    static func record(from dto: CoachRecordDTO, league: League) -> CoachRecord? {
        let label = (dto.type ?? dto.name ?? "").lowercased()
        let kind: CoachRecord.Kind
        if label.contains("post") || dto.id?.value == "3" {
            kind = .postseason
        } else if label.contains("regular") || dto.id?.value == "2" {
            kind = .regular
        } else if label.contains("total") || dto.id?.value == "0" {
            kind = .total
        } else {
            return nil
        }
        let stats = (dto.stats?.elements ?? []).reduce(into: [String: Int]()) { out, stat in
            if let name = stat.name, let value = stat.value { out[name] = Int(value.rounded()) }
        }
        guard let wins = stats["wins"], let losses = stats["losses"] else { return nil }
        // Three spellings of one stat: the NFL's payload says `OTLosses`,
        // the NHL's says `otLosses` and `overtimeLosses` both (probed
        // 2026-09-27, Tocchet's 2019-20: "33-29-0-8").
        let overtimeLosses = stats["overtimeLosses"] ?? stats["otLosses"] ?? stats["OTLosses"] ?? 0
        return CoachRecord(kind: kind, wins: wins, losses: losses,
                           ties: stats["ties"] ?? 0,
                           overtimeLosses: league == .nhl ? overtimeLosses : 0)
    }

    /// Career lines in reading order, one per kind. College football ships
    /// Total and Regular Season identical and no postseason, so a regular
    /// line equal to the total says nothing twice and is dropped.
    static func careerRecords(_ records: [CoachRecord]) -> [CoachRecord] {
        var byKind: [CoachRecord.Kind: CoachRecord] = [:]
        for record in records where byKind[record.kind] == nil { byKind[record.kind] = record }
        if let total = byKind[.total], let regular = byKind[.regular], byKind[.postseason] == nil,
           total.wins == regular.wins, total.losses == regular.losses, total.ties == regular.ties {
            byKind[.regular] = nil
        }
        return byKind.values.filter { $0.games > 0 }.sorted { $0.kind < $1.kind }
    }

    /// `…/seasons/2016/coaches/7157?lang=en` → 2016, ESPN's year.
    static func seasonYear(inRef ref: String?) -> Int? {
        guard let ref, let tail = ref.components(separatedBy: "/seasons/").last else { return nil }
        return Int(tail.prefix { $0.isNumber })
    }

    /// One row per team the season names. The record is the coach's for the
    /// season, so a season listing two teams (never seen, but the payload is
    /// an array) gives each the line only when there's one team to give it.
    static func seasons(from dto: CoachSeasonDTO?, espnYear: Int, record: CoachRecord?,
                        league: League) -> [CoachSeason] {
        let teamIds = (dto?.records?.elements ?? []).compactMap { $0.team?.teamId }
        let unique = teamIds.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return unique.map {
            CoachSeason(year: league.seasonYear(fromESPN: espnYear), teamId: $0,
                        record: unique.count == 1 ? record : nil)
        }
    }

    /// Newest first, duplicates gone, and no season the coach didn't coach.
    ///
    /// ESPN lists the season a coach left as a zero-game row at the old
    /// team — Kalen DeBoer reads "2024 Washington 0-0" (twice) for the year
    /// DeBoer was at Alabama. A season with a record of no games is that row.
    /// A season with *no* record is kept: the current one, before kickoff,
    /// answers 404 and is still the job.
    static func cleaned(_ seasons: [CoachSeason]) -> [CoachSeason] {
        var seen = Set<String>()
        return seasons
            .filter { season in
                if let record = season.record, record.games == 0 { return false }
                return seen.insert(season.id).inserted
            }
            .sorted { $0.year != $1.year ? $0.year > $1.year : $0.teamId < $1.teamId }
    }
}

// MARK: - DTOs

nonisolated struct CoachPersonDTO: Decodable {
    let id: FlexibleID?
    let firstName: String?
    let lastName: String?
    let dateOfBirth: String?
    let birthPlace: CoachBirthPlaceDTO?
    let college: CoreRefDTO?
    let headshot: CoachHeadshotDTO?
    let experience: Int?
    let careerRecords: LossyArray<CoreRefDTO>?
    let coachSeasons: LossyArray<CoreRefDTO>?
}

nonisolated struct CoachBirthPlaceDTO: Decodable {
    let city: String?
    let state: String?
    let country: String?
}

nonisolated struct CoachHeadshotDTO: Decodable {
    let href: String?
}

nonisolated struct CoachRecordDTO: Decodable {
    let id: FlexibleID?
    let name: String?
    let type: String?
    let stats: LossyArray<CoachRecordStatDTO>?
}

nonisolated struct CoachRecordStatDTO: Decodable {
    let name: String?
    let value: Double?
}

nonisolated struct CoachSeasonDTO: Decodable {
    let records: LossyArray<CoachSeasonRecordDTO>?
}

nonisolated struct CoachSeasonRecordDTO: Decodable {
    let team: CoreRefDTO?
    let record: CoreRefDTO?
}

nonisolated struct CollegeDTO: Decodable {
    let name: String?
    let shortName: String?
}

nonisolated struct CoachTeamDTO: Decodable {
    let displayName: String?
    let name: String?
    let abbreviation: String?
    let logos: LossyArray<CoachHeadshotDTO>?
}
