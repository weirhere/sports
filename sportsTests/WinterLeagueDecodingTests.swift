import Foundation
import Testing
@testable import StatSide

private final class WinterFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: WinterFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

/// The premise the league axis was built on, tested one sport further out:
/// ESPN serves basketball and hockey through the same shapes as football,
/// so the DTO layer needs no second decoder. Fixtures captured live
/// 2026-09-08.
@Suite struct WinterScoreboardDecoding {

    @Test func bothScoreboardsDecodeThroughTheSameDTOs() throws {
        for (name, league) in [("nba-scoreboard", League.nba), ("nhl-scoreboard", .nhl)] {
            let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture(name))
            let board = ESPNMapper.scoreboard(from: dto, league: league)

            #expect(!board.games.isEmpty, "\(league) fixture should carry games")
            let game = try #require(board.games.first)
            #expect(!game.home.team.location.isEmpty)
            #expect(game.away.team.abbreviation != nil)
            #expect(game.home.team.league == league)
        }
    }

    /// ESPN ships two different things under `leagues[].calendar`, and
    /// which one you get depends on the league *and* the request:
    /// football's labelled week periods, or — for these two, whose
    /// `calendarType` is "day" — a flat list of ~229 ISO date strings.
    ///
    /// That form used to throw, and because `leagues` was a plain array
    /// the throw took the whole scoreboard with it: every event of a
    /// single-day NBA or NHL request, lost to a field nothing reads for
    /// those leagues. A date *range* returns an empty calendar, which is
    /// why it stayed hidden until a one-day fixture was captured.
    @Test func aDayListCalendarCostsTheWeeksAndNothingElse() throws {
        for name in ["nba-scoreboard", "nhl-scoreboard"] {
            let raw = try #require(try JSONSerialization.jsonObject(
                with: fixture(name)) as? [String: Any])
            let leagues = try #require(raw["leagues"] as? [[String: Any]])
            let calendar = try #require(leagues.first?["calendar"] as? [Any])
            // The premise: it really is a list of bare strings.
            #expect(calendar.count > 100)
            #expect(calendar.first is String)

            let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture(name))
            #expect(ESPNMapper.weekSlots(from: dto).isEmpty)
            let events = dto.events?.elements ?? []
            #expect(events.count > 0, "the slate survived the calendar")
        }
    }

    /// These scoreboards ship no week, which is why the day strip is the
    /// only axis they could ever have had.
    @Test func aWinterScoreboardCarriesNoWeeks() throws {
        for name in ["nba-scoreboard", "nhl-scoreboard"] {
            let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture(name))
            #expect(ESPNMapper.weekSlots(from: dto).isEmpty)
            #expect(ESPNMapper.scoreboard(from: dto, league: .nba).games
                .allSatisfy { $0.weekNumber == nil })
        }
    }

    /// The scoreboard payload carries no group id, so a team's conference
    /// comes entirely from the hardcoded registry — this is the assertion
    /// that would fail if a map were mistyped.
    @Test func everyTeamOnTheSlateResolvesToARealConference() throws {
        for (name, league) in [("nba-scoreboard", League.nba), ("nhl-scoreboard", .nhl)] {
            let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture(name))
            let board = ESPNMapper.scoreboard(from: dto, league: league)
            for game in board.games {
                for side in [game.home, game.away] {
                    let conference = try #require(side.team.conference,
                                                  "\(side.team.id) has no conference")
                    #expect(Conference.tier(for: conference.id, in: league) == .division)
                    #expect(Conference.chain(for: conference).count == 3)
                }
            }
        }
    }
}

@Suite struct WinterStandingsDecoding {

    @Test func bothStandingsMapOntoTheRegistrysConferences() throws {
        let expected: [(String, League, [Int])] = [
            ("nba-standings", .nba, [5, 6]),
            ("nhl-standings", .nhl, [7, 8]),
        ]
        for (name, league, ids) in expected {
            let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
            let tables = ESPNMapper.conferenceStandings(from: dto, league: league)
            #expect(tables.map(\.id) == ids)
            #expect(tables.allSatisfy { !$0.entries.isEmpty })
            #expect(tables.map(\.name) == ["Eastern", "Western"])
        }
    }

    @Test func theDivisionalResponseNestsUnderTheRightConferences() throws {
        let expected: [(String, League, Int)] = [
            ("nba-standings-level3", .nba, 6),
            ("nhl-standings-level3", .nhl, 4),
        ]
        for (name, league, count) in expected {
            let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
            let divisions = ESPNMapper.divisionStandings(from: dto, league: league)
            #expect(divisions.count == count)
            for division in divisions {
                let parent = try #require(division.parentId)
                #expect(Conference.topLevelIds(in: league).contains(parent))
                #expect(!division.entries.isEmpty)
            }
        }
    }

    /// The hub lists divisions now (Andy, 2026-09-09), so a pro league's
    /// one request is the divisional one — and everything above a division
    /// has to be derivable from it, or the league row and any standing
    /// conference follow would vanish with the fetch they used to have.
    @Test func aDivisionalResponseStillFoldsBackUpToConferencesAndTheLeague() throws {
        let expected: [(String, League, [Int])] = [
            ("nba-standings-level3", .nba, [5, 6]),
            ("nhl-standings-level3", .nhl, [7, 8]),
        ]
        for (name, league, conferenceIds) in expected {
            let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
            let divisions = ESPNMapper.divisionStandings(from: dto, league: league)

            // Folded: one row per conference, with every division's teams.
            let conferences = divisions.foldingDivisions()
            #expect(Set(conferences.compactMap(\.id)) == Set(conferenceIds))
            #expect(conferences.allSatisfy { $0.parentId == nil })
            for conference in conferences {
                let members = divisions
                    .filter { $0.parentId == conference.id }
                    .flatMap(\.entries)
                #expect(conference.entries.count == members.count)
            }

            // And the whole league merges out of the folded conferences,
            // ranked, exactly as it did from the shallower response.
            let table = try #require(conferences.leagueTable(in: league))
            #expect(table.entries.count == divisions.flatMap(\.entries).count)
            #expect(table.id == Conference.leagueWideId(in: league))
            #expect(table.leader != nil)
        }
    }

    /// A division's own order is ESPN's, which is what a leader teaser on
    /// the hub reads — never re-sorted here.
    @Test func everyDivisionKnowsItsLeader() throws {
        for (name, league) in [("nba-standings-level3", League.nba),
                               ("nhl-standings-level3", .nhl)] {
            let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
            for division in ESPNMapper.divisionStandings(from: dto, league: league) {
                #expect(division.leader != nil, "\(division.name) has no leader")
                #expect(Conference.tier(for: division.id, in: league) == .division)
            }
        }
    }

    /// Grouped by conference, alphabetical inside it. The mapper sorts by
    /// name alone, which interleaves the NBA's six — Northwest between
    /// Central and Pacific, with nothing on screen to explain why.
    @Test func theHubGroupsDivisionsByTheirConference() throws {
        let expected: [(String, League, [String])] = [
            ("nba-standings-level3", .nba,
             ["Atlantic", "Central", "Southeast", "Northwest", "Pacific", "Southwest"]),
            ("nhl-standings-level3", .nhl,
             ["Atlantic", "Metropolitan", "Central", "Pacific"]),
        ]
        for (name, league, order) in expected {
            let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
            let divisions = ESPNMapper.divisionStandings(from: dto, league: league)
            let conferenceOrder = Conference.topLevelIds(in: league)
            let grouped = divisions.sorted { lhs, rhs in
                let l = lhs.parentId.flatMap(conferenceOrder.firstIndex(of:)) ?? conferenceOrder.count
                let r = rhs.parentId.flatMap(conferenceOrder.firstIndex(of:)) ?? conferenceOrder.count
                return l == r ? lhs.name < rhs.name : l < r
            }
            #expect(grouped.map(\.name) == order)
        }
    }

    /// The NHL keeps no conference record and ranks on points; the NBA
    /// keeps win percentage and games back. Each table's columns have to
    /// find numbers in the payload the league actually ships.
    @Test func everyLeaguesColumnsFindTheirNumbers() throws {
        for (name, league) in [("nba-standings", League.nba), ("nhl-standings", .nhl)] {
            let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
            let table = try #require(ESPNMapper.conferenceStandings(from: dto, league: league).first)
            let leader = try #require(table.entries.first)
            for column in league.standingsColumns {
                #expect(leader.value(for: column) != nil,
                        "\(league) \(column.caption) found nothing")
            }
        }
    }

    @Test func theNHLRecordIsComposedNotTakenFromTheSummary() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("nhl-standings"))
        let table = try #require(ESPNMapper.conferenceStandings(from: dto, league: .nhl).first)
        let leader = try #require(table.entries.first)
        // ESPN's own `total` summary here is "53-22-7, 113 PTS".
        #expect(leader.winLossOTL?.split(separator: "-").count == 3)
        #expect(leader.overallRecord?.contains("PTS") == false)
        #expect(leader.conferenceRecord == nil)
        #expect((leader.points ?? 0) > 0)
        #expect(leader.hasPlayed)
    }

    /// A points ranking, because the NHL ships no win percentage — without
    /// it the 32-team table came back East's seeds then West's.
    @Test func theNHLLeagueTableRanksOnPoints() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("nhl-standings"))
        let tables = ESPNMapper.conferenceStandings(from: dto, league: .nhl)
        let league = try #require(tables.leagueTable(in: .nhl))

        #expect(league.entries.count == 32)
        let points = league.entries.compactMap(\.points)
        #expect(points.count == 32)
        #expect(points == points.sorted(by: >))
    }

    @Test func theNBALeagueTableStillRanksOnWinPercentage() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("nba-standings"))
        let tables = ESPNMapper.conferenceStandings(from: dto, league: .nba)
        let league = try #require(tables.leagueTable(in: .nba))

        #expect(league.entries.count == 30)
        let percents = league.entries.compactMap(\.winPercent)
        #expect(percents == percents.sorted(by: >))
    }
}

@Suite struct WinterScheduleDecoding {

    /// A whole 82-game season in one request, which is what makes a team
    /// page's Games tab affordable where a conference page's is not.
    @Test func aWholeSeasonArrivesInOneRequest() throws {
        for (name, league, teamId) in [("nba-team-schedule", League.nba, "13"),
                                       ("nhl-team-schedule", .nhl, "21")] {
            let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture(name))
            let schedule = ESPNMapper.teamSchedule(from: dto, league: league)
            #expect(schedule.games.count == 82, "\(league) should carry a full season")
            #expect(schedule.team?.id == teamId)
        }
    }

    /// The schedule payload *does* carry the team's group, unlike the
    /// scoreboard — and it's the division, with the conference as parent.
    @Test func theSchedulePayloadNamesTheTeamsDivision() throws {
        let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture("nhl-team-schedule"))
        let schedule = ESPNMapper.teamSchedule(from: dto, league: .nhl)
        // Toronto plays in the Atlantic (32).
        #expect(schedule.team?.conferenceId == 32)
        #expect(Conference.parent(of: 32, in: .nhl) == 7)
    }

    /// ESPN answered a `season=2027` request, and the page that asked knows
    /// that season as 2026. The translation happens at the boundary and
    /// nowhere else.
    @Test func theSeasonComesBackOnOurOwnAxis() throws {
        let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture("nba-team-schedule"))
        #expect(dto.requestedSeason?.year == 2026)
        #expect(ESPNMapper.teamSchedule(from: dto, league: .nba).year == 2025)
        // Football's axis is ESPN's, so nothing moves there.
        #expect(ESPNMapper.teamSchedule(from: dto, league: .nfl).year == 2026)
    }
}

@Suite struct WinterSummaryDecoding {

    /// **The regression this fixture exists for.** Football splits its box
    /// score into named groups; basketball ships one group with
    /// `name: null`, because there is only one table to ship. The mapper
    /// required a name, so every NBA box score was dropped on the floor —
    /// and silently, since an empty box score is exactly how the tab hides
    /// itself for a game that has none.
    @Test func theNBABoxScoreSurvivesItsUnnamedGroup() throws {
        let raw = try #require(try JSONSerialization.jsonObject(
            with: fixture("nba-summary")) as? [String: Any])
        let players = try #require(
            (raw["boxscore"] as? [String: Any])?["players"] as? [[String: Any]])
        let groups = try #require(players.first?["statistics"] as? [[String: Any]])
        // The premise: ESPN really does send one group with no name.
        #expect(groups.count == 1)
        #expect(groups.first?["name"] == nil)

        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("nba-summary"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .nba)
        #expect(summary.boxScore.count == 2)
        let category = try #require(summary.boxScore.first?.categories.first)
        // Columns come from the payload's own labels, which is what makes
        // a basketball box score work with no schema of ours at all.
        #expect(category.columns.contains("PTS"))
        #expect(category.columns.contains("REB"))
        #expect(!category.players.isEmpty)
        #expect(category.players.allSatisfy { $0.stats.count == category.columns.count })
    }

    /// Hockey names its groups, and ships one ("skaters") with nobody in
    /// it — which the existing empty-group rule already drops.
    @Test func theNHLBoxScoreKeepsItsNamedGroupsAndDropsTheEmptyOne() throws {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("nhl-summary"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .nhl)
        let labels = summary.boxScore.first?.categories.map(\.label) ?? []
        #expect(labels.contains { $0.lowercased().contains("forward") })
        #expect(labels.contains { $0.lowercased().contains("goalie") })
        #expect(!labels.contains { $0.lowercased() == "skaters" })
    }

    /// No drives means no Gamecast strip and no drive log — the football
    /// cards retire themselves, which is the whole reason they could.
    @Test func aWinterSummaryHasNoDrivesAndKeepsItsPlays() throws {
        for (name, league) in [("nba-summary", League.nba), ("nhl-summary", .nhl)] {
            let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture(name))
            let summary = ESPNMapper.gameSummary(from: dto, league: league)
            #expect(summary.drives.isEmpty)
            #expect(summary.currentDrive == nil)
            #expect(summary.situation == nil)
            #expect(summary.plays.count > 100, "\(league) should carry a flat play feed")
            #expect(summary.plays.allSatisfy { $0.period != nil })
        }
    }

    /// Football's plays live inside its drives, so the flat feed stays
    /// empty there — carrying them twice would print the same rows in two
    /// places.
    @Test func aFootballSummaryKeepsItsPlaysInItsDrives() throws {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self,
                                           from: fixture("summary-final-live"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .collegeFootball)
        #expect(!summary.drives.isEmpty)
        #expect(summary.plays.isEmpty)
    }

    /// A goal is an event, so hockey gets the Scoring slot — derived from
    /// the play feed, because ESPN ships no `scoringPlays` for it. Every
    /// row has to know whose goal it was, which is what `PlayDTO.team`
    /// was decoded for.
    @Test func hockeyGoalsBecomeTheScoringCard() throws {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("nhl-summary"))
        #expect(dto.scoringPlays?.isEmpty != false, "ESPN ships none for the NHL")

        let summary = ESPNMapper.gameSummary(from: dto, league: .nhl)
        #expect(!summary.scoringPlays.isEmpty)
        #expect(summary.scoringPlays.allSatisfy { $0.teamId != nil })
        #expect(League.nhl.scoringCardTitle == "Goals")

        // The four real goals of a 2-2 game, and none of the three
        // shootout attempts: ESPN flags every attempt as a scoring play
        // and stamps it with the shootout tally rather than the game
        // score, so listing them put three goals on the card whose
        // running score went nowhere. A shootout is one goal, awarded at
        // the end, and the line score's SO column is where it shows.
        #expect(summary.scoringPlays.count == 4)
        #expect(summary.scoringPlays.allSatisfy { ($0.period ?? 0) <= 4 })
        #expect(summary.plays.filter(\.isScoringPlay).count == 7)
    }

    /// Basketball scores ~98 times a game. A chronological list of every
    /// bucket is the box score with worse formatting, so there is no card
    /// and nothing is derived for one.
    @Test func basketballGetsNoScoringCard() throws {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("nba-summary"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .nba)
        #expect(summary.scoringPlays.isEmpty)
        #expect(League.nba.scoringCardTitle == nil)
        // The plays themselves are still there — the Plays tab wants them.
        #expect(summary.plays.contains { $0.isScoringPlay })
    }

    /// Leaders come from the league's own categories, and a running score
    /// still attributes the side that scored.
    @Test func leadersAndScoringSidesComeThroughForBothLeagues() throws {
        let expected: [(String, League, Set<String>)] = [
            ("nba-summary", .nba, ["points", "rebounds", "assists"]),
            ("nhl-summary", .nhl, ["goals", "assists", "points"]),
        ]
        for (name, league, categories) in expected {
            let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture(name))
            let summary = ESPNMapper.gameSummary(from: dto, league: league)
            #expect(!summary.leaders.isEmpty)
            #expect(Set(summary.leaders.map(\.id)).isSubset(of: categories))
            #expect(summary.leaders.contains { $0.away?.headshotURL != nil })
        }
    }

    /// A goal is attributed by the side whose number went up — never by
    /// the play's own team, because that is the rule a pick six breaks in
    /// football and a shootout breaks here.
    ///
    /// This fixture is a shootout game on purpose. Every shootout attempt
    /// arrives flagged as a scoring play, and none of them moves the score
    /// (the winner is awarded one goal at the end), so they are correctly
    /// attributed to nobody. The invariant is the conditional one: a play
    /// is attributed exactly when the running score advanced.
    @Test func aGoalIsAttributedByTheScoreThatMoved() throws {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("nhl-summary"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .nhl)
        let scoring = summary.plays.filter(\.isScoringPlay)
        #expect(!scoring.isEmpty)

        var away = 0
        var home = 0
        var advanced = 0
        for play in summary.plays {
            guard let a = play.awayScore, let h = play.homeScore else { continue }
            if play.isScoringPlay {
                let moved = a > away || h > home
                #expect((play.scoringSide != nil) == moved)
                if moved { advanced += 1 }
            }
            away = a
            home = h
        }
        #expect(advanced > 0, "some goal has to have moved the score")
        // And the shootout is why this fixture was chosen: some scoring
        // play here genuinely didn't.
        #expect(advanced < scoring.count)
    }

    /// The compare card was silently empty for these leagues, because the
    /// stat names it asked for are football's.
    @Test func theCompareCardFindsEachLeaguesOwnStats() throws {
        for (name, league) in [("nba-summary", League.nba), ("nhl-summary", .nhl)] {
            let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture(name))
            let summary = ESPNMapper.gameSummary(from: dto, league: league)
            #expect(!summary.teamStats.isEmpty, "\(league) compare card found nothing")
        }
    }
}

@Suite struct PeriodLabelTests {

    @Test func aPeriodIsCalledWhateverItsLeagueCallsIt() {
        #expect(PeriodLabel.text(1, in: .nba) == "1ST QUARTER")
        #expect(PeriodLabel.text(4, in: .nba) == "4TH QUARTER")
        #expect(PeriodLabel.text(1, in: .nhl) == "1ST PERIOD")
        #expect(PeriodLabel.text(3, in: .nhl) == "3RD PERIOD")
        #expect(PeriodLabel.text(1, in: .collegeFootball) == "1ST QUARTER")
        #expect(PeriodLabel.text(nil, in: .nhl) == "—")
    }

    /// Hockey plays three periods, so its overtime is the fourth — where
    /// football's and basketball's is the fifth.
    @Test func overtimeStartsWhereRegulationEnds() {
        #expect(PeriodLabel.text(4, in: .nhl) == "OVERTIME")
        #expect(PeriodLabel.text(5, in: .nba) == "OVERTIME")
        #expect(PeriodLabel.text(6, in: .nba) == "2OT")
        #expect(PeriodLabel.text(5, in: .collegeFootball) == "OVERTIME")
    }

    /// The NHL settles a regular-season tie in a shootout after the
    /// overtime, which arrives as period 5 (`Final/SO`, verified live).
    /// A playoff period 5 is a second overtime, so the label is only ever
    /// offered where the game could actually have one.
    @Test func aFifthHockeyPeriodIsAShootoutOnlyInTheRegularSeason() {
        #expect(PeriodLabel.text(5, in: .nhl, allowsShootout: true) == "SHOOTOUT")
        #expect(PeriodLabel.text(5, in: .nhl, allowsShootout: false) == "2OT")
        #expect(PeriodLabel.short(5, in: .nhl, allowsShootout: true) == "SO")
        #expect(PeriodLabel.short(4, in: .nhl) == "OT")
        #expect(PeriodLabel.short(2, in: .nhl) == "2")
    }

    /// The live status line says P2 in hockey where it says Q2 in
    /// football, and it never says "shootout" — a shootout arrives as a
    /// final, never as a running clock.
    @Test func theLiveClockUsesTheLeaguesOwnPeriodLetter() {
        #expect(GameStatus.periodLabel(2, in: .nhl) == "P2")
        #expect(GameStatus.periodLabel(2, in: .nba) == "Q2")
        #expect(GameStatus.periodLabel(4, in: .nhl) == "OT")
        #expect(GameStatus.periodLabel(5, in: .nhl) == "2OT")
        #expect(GameStatus.periodLabel(5, in: .nba) == "OT")
    }
}
