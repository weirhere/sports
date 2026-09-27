import Foundation
import Testing
@testable import StatSide

private final class FixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: FixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private func team(_ id: String, _ location: String) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 8)
}

private let wsu = team("265", "Washington State")
private let washington = team("264", "Washington")

private func play(id: String = "p",
                  text: String? = "Shotgun #20 L.Pulalasi rush middle for 6 yards",
                  down: String? = "1st & 10 at WSU 20",
                  next: String? = "2nd & 4",
                  spot: String? = "WSU 26",
                  yardsToEndzone: Int? = nil,
                  clock: String? = "7:53",
                  period: Int? = 2,
                  type: String? = "Rush",
                  scoring: Bool = false,
                  away: Int? = nil, home: Int? = nil) -> Play {
    Play(id: id, text: text, downDistanceText: down, nextDownDistanceText: next,
         possessionText: spot, yardsToEndzone: yardsToEndzone, clock: clock,
         period: period, typeText: type, isScoringPlay: scoring,
         awayScore: away, homeScore: home)
}

private func summary(current: Drive?, drives: [Drive] = []) -> GameSummary {
    GameSummary(
        home: GameSummary.Side(team: washington, score: 10, record: nil,
                               rank: nil, winner: nil, linescores: []),
        away: GameSummary.Side(team: wsu, score: 0, record: nil,
                               rank: nil, winner: nil, linescores: []),
        status: .live(displayClock: "7:53", period: 2, detail: nil,
                      phase: .playing, possessionTeamId: wsu.id),
        scoringPlays: [], drives: drives, currentDrive: current,
        teamStats: [], leaders: [], venue: nil, attendance: nil)
}

/// The Plays tab's whole reason to exist: ESPN ships the plays inside
/// each drive and we used to drop them at the decoder.
@Suite struct PlayDecodingTests {
    private func loadSummary() throws -> GameSummary {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("summary-final-live"))
        return ESPNMapper.gameSummary(from: dto)
    }

    @Test func drivesCarryTheirPlays() throws {
        let summary = try loadSummary()
        #expect(summary.drives.count == 22)
        #expect(summary.drives.allSatisfy { !$0.plays.isEmpty })

        let opening = try #require(summary.drives.first)
        #expect(opening.plays.count == 7)
        let kickoff = try #require(opening.plays.first)
        #expect(kickoff.typeText == "Kickoff")
        #expect(kickoff.clock == "14:55")
        #expect(kickoff.period == 1)
        #expect(kickoff.isScoringPlay == false)
        // A kickoff has no down of its own; the row falls back to the type.
        #expect(kickoff.downDistanceText == nil)
        // Its end is where the next snap happens.
        #expect(kickoff.nextDownDistanceText == "1st & 10")
        #expect(kickoff.possessionText == "MIA 28")
    }

    @Test func playsCarryTheirDown() throws {
        let summary = try loadSummary()
        let drive = summary.drives[1]
        let first = try #require(drive.plays.first)
        #expect(first.downDistanceText == "1st & 10 at IU 5")
        #expect(first.text?.contains("F.Mendoza") == true)
    }

    @Test func scoringPlaysAreFlagged() throws {
        let summary = try loadSummary()
        let scoring = summary.drives.flatMap(\.scoringPlays)
        #expect(!scoring.isEmpty)
        #expect(scoring.allSatisfy { $0.isScoringPlay })
        // Every scoring play carries the score it produced, which is what
        // the Plays tab prints beside it.
        #expect(scoring.allSatisfy { $0.awayScore != nil && $0.homeScore != nil })
        // The whole-game scoring list and the per-drive one agree.
        #expect(scoring.count == summary.scoringPlays.count)
    }

    /// A final game has no possession in progress, so the Gamecast strip
    /// retires itself without the screen testing the clock.
    @Test func finalGameHasNoCurrentDrive() throws {
        let summary = try loadSummary()
        #expect(summary.currentDrive == nil)
        #expect(summary.situation == nil)
    }

    /// The reason attribution reads the score rather than the drive's
    /// team: this game's blocked-punt touchdown happened on Miami's
    /// drive and put Indiana's points on the board.
    @Test func scoringSideComesFromTheScoreNotThePossession() throws {
        let summary = try loadSummary()
        let scoring = summary.drives.flatMap { drive in
            drive.scoringPlays.map { (drive: drive, play: $0) }
        }
        #expect(scoring.map(\.play.scoringSide) ==
                [.home, .home, .away, .home, .away, .home, .away, .home])

        let blocked = try #require(scoring.first { $0.play.typeText == "Blocked Punt Touchdown" })
        // Miami had the ball; Indiana got the points.
        #expect(summary.team(withId: blocked.drive.teamId)?.abbreviation == "MIA")
        #expect(blocked.play.scoringSide == .home)
        #expect(summary.home?.team.abbreviation == "IU")
    }

    @Test func nonScoringPlaysAreNeverAttributed() throws {
        let summary = try loadSummary()
        let quiet = summary.drives.flatMap(\.plays).filter { !$0.isScoringPlay }
        #expect(!quiet.isEmpty)
        #expect(quiet.allSatisfy { $0.scoringSide == nil })
    }

    @Test func everyPlayHasAUniqueId() throws {
        let summary = try loadSummary()
        let ids = summary.drives.flatMap { $0.plays.map(\.id) }
        #expect(Set(ids).count == ids.count)
    }
}

/// The field bar's arithmetic. `yardsToEndzone` counts toward whichever
/// end zone the offense is attacking, so the same number means opposite
/// ends of the bar depending on who has the ball.
@Suite struct GameSituationTests {
    @Test func awayPossessionReadsFromTheLeft() throws {
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false,
                          summary: "1 play, 6 yards, 0:05", period: 2,
                          plays: [play(yardsToEndzone: 74)])
        let situation = try #require(summary(current: drive).situation)
        // 74 to go for the away team = its own 26 = a quarter of the way
        // along a bar drawn away-end-zone-left.
        #expect(situation.fieldPosition == 0.26)
        #expect(situation.drivingRight)
        #expect(situation.downDistanceText == "2nd & 4")
        #expect(situation.possessionText == "WSU 26")
        #expect(situation.driveSummary == "1 play, 6 yards, 0:05")
    }

    @Test func homePossessionReadsFromTheRight() throws {
        let drive = Drive(id: "d", teamId: washington.id, result: nil, isScore: false,
                          summary: nil, period: 2, plays: [play(yardsToEndzone: 26)])
        let situation = try #require(summary(current: drive).situation)
        // The home team attacks the left end zone, so 26 to go puts the
        // ball a quarter along the same bar.
        #expect(situation.fieldPosition == 0.26)
        #expect(situation.drivingRight == false)
    }

    @Test func fieldPositionClampsPastTheGoalLine() throws {
        let over = Drive(id: "d", teamId: wsu.id, result: nil, isScore: true,
                         summary: nil, period: 2, plays: [play(yardsToEndzone: -3)])
        #expect(summary(current: over).situation?.fieldPosition == 1)
        let under = Drive(id: "d", teamId: wsu.id, result: nil, isScore: true,
                          summary: nil, period: 2, plays: [play(yardsToEndzone: 103)])
        #expect(summary(current: under).situation?.fieldPosition == 0)
    }

    @Test func noDistanceLeavesTheBarOffAndTheRestStanding() throws {
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false,
                          summary: nil, period: 2, plays: [play(yardsToEndzone: nil)])
        let situation = try #require(summary(current: drive).situation)
        #expect(situation.fieldPosition == nil)
        #expect(situation.downDistanceText == "2nd & 4")
    }

    /// A drive with no plays on it yet — the possession has changed hands
    /// but nothing has been snapped — has nothing to describe.
    @Test func emptyDriveHasNoSituation() {
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false,
                          summary: nil, period: 2, plays: [])
        #expect(summary(current: drive).situation == nil)
    }

    /// A drive whose team we can't place (CFBD's school-name join can
    /// miss) still reads its down and spot; only the direction defaults.
    @Test func unknownPossessionStillDescribesTheDown() throws {
        let drive = Drive(id: "d", teamId: "9999", result: nil, isScore: false,
                          summary: nil, period: 2, plays: [play(yardsToEndzone: 74)])
        let situation = try #require(summary(current: drive).situation)
        #expect(situation.downDistanceText == "2nd & 4")
        #expect(situation.drivingRight == false)
    }
}

@MainActor
@Suite struct PlayAccessibilityTests {
    private func list(_ model: GameSummary) -> PlayByPlayList {
        PlayByPlayList(summary: model, scoringOnly: false)
    }

    @Test func playSpeaksDownClockAndNarration() {
        let model = summary(current: nil)
        #expect(list(model).accessibilitySummary(for: play()) ==
                "1st & 10 at WSU 20, 7:53, Shotgun #20 L.Pulalasi rush middle for 6 yards")
    }

    @Test func aScoringPlaySpeaksTheRunningScore() {
        let model = summary(current: nil)
        let scored = play(text: "N.Radicic 34 Yd Field Goal", scoring: true, away: 0, home: 3)
        #expect(list(model).accessibilitySummary(for: scored) ==
                "1st & 10 at WSU 20, 7:53, N.Radicic 34 Yd Field Goal, Washington State 0, Washington 3")
    }

    /// A kickoff has no down, so the play's type carries the line — the
    /// same fallback the sighted row makes.
    @Test func aPlayWithNoDownSpeaksItsType() {
        let model = summary(current: nil)
        let kickoff = play(text: "B.Franke kickoff 64 yards", down: nil, type: "Kickoff")
        #expect(list(model).accessibilitySummary(for: kickoff) ==
                "Kickoff, 7:53, B.Franke kickoff 64 yards")
    }

    @Test func driveSpeaksTeamResultAndLine() {
        let model = summary(current: nil)
        let drive = Drive(id: "d", teamId: wsu.id, result: "Punt", isScore: false,
                          summary: "5 plays, 20 yards, 2:39", period: 1)
        #expect(list(model).accessibilitySummary(for: drive) ==
                "Washington State, punt, 5 plays, 20 yards, 2:39")
    }

    @Test func situationCardSpeaksTheWholeStrip() throws {
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false,
                          summary: "1 play, 6 yards, 0:05", period: 2,
                          plays: [play(yardsToEndzone: 74)])
        let model = summary(current: drive)
        let situation = try #require(model.situation)
        let card = LiveSituationCard(summary: model, situation: situation)
        #expect(card.accessibilitySummary ==
                "Washington State ball, 2nd & 4, WSU 26, 1 play, 6 yards, 0:05, "
                + "Shotgun #20 L.Pulalasi rush middle for 6 yards")
    }
}

/// The Gamecast card's data (2026-09-27): what the mapper now keeps from
/// ESPN's drive and play shapes.
@Suite struct GamecastMappingTests {
    private func loadSummary() throws -> GameSummary {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("summary-final-live"))
        return ESPNMapper.gameSummary(from: dto)
    }

    /// ESPN leads every narration with its clock, and every surface
    /// prints the clock beside the text — so it printed twice.
    @Test func playTextLosesItsLeadingClock() throws {
        let summary = try loadSummary()
        let rush = try #require(summary.drives.first?.plays.dropFirst().first)
        #expect(rush.text?.hasPrefix("Shotgun #4 M.Fletcher Jr.") == true)
        #expect(summary.drives.flatMap(\.plays).allSatisfy {
            $0.text?.firstMatch(of: #/^\(\d{1,2}:\d{2}\)/#) == nil
        })
    }

    @Test func onlyALeadingClockIsStripped() {
        #expect(ESPNMapper.playText("(9:34) (Shotgun) T.Brady pass deep left") == "(Shotgun) T.Brady pass deep left")
        #expect(ESPNMapper.playText("L.Blount left end pushed ob (J.Taylor).") == "L.Blount left end pushed ob (J.Taylor).")
        #expect(ESPNMapper.playText("  (11:28) L.Blount left end ") == "L.Blount left end")
        // A clock and nothing else keeps the clock rather than going blank.
        #expect(ESPNMapper.playText("(0:00)") == "(0:00)")
    }

    /// A snap starts and ends with the same team; a kickoff doesn't, and
    /// its two spots are measured toward different end zones.
    @Test func onlyASnapKeepsItsStartSpot() throws {
        let summary = try loadSummary()
        let opening = try #require(summary.drives.first)
        #expect(opening.plays.first?.typeText == "Kickoff")
        #expect(opening.plays.first?.startYardsToEndzone == nil)
        #expect(opening.plays.dropFirst().first?.startYardsToEndzone == 72)
        #expect(opening.plays.dropFirst().first?.nextDistance == 1)
    }

    @Test func drivesCarryTheirPlayCountAndYards() throws {
        let opening = try #require(try loadSummary().drives.first)
        #expect(opening.offensivePlays == 5)
        #expect(opening.yards == 20)
        #expect(GameSummary.driveLine(opening) == "5 plays, 20 yds")
    }

    @Test func sidesCarryTheirColors() throws {
        let summary = try loadSummary()
        #expect(summary.home?.team.abbreviation == "IU")
        #expect(summary.home?.color == "970310")
        #expect(summary.home?.alternateColor == "ffffff")
    }
}

/// The field's geometry, all in yards from the away goal line.
@Suite struct GamecastFieldTests {
    private func snap(id: String, from start: Int, to end: Int, type: String = "Rush",
                      distance: Int? = 10, scoring: Bool = false) -> Play {
        var p = play(id: id, yardsToEndzone: end, type: type, scoring: scoring)
        p.startYardsToEndzone = start
        p.nextDistance = distance
        return p
    }

    @Test func awayDriveReadsLeftToRight() throws {
        // WSU (away) from its own 25 to the ORST... well, Washington 18.
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false, summary: nil,
                          period: 2, plays: [snap(id: "1", from: 75, to: 69),
                                             snap(id: "2", from: 52, to: 18, type: "Pass Reception")],
                          offensivePlays: 2, yards: 57)
        let situation = try #require(summary(current: drive).situation)
        let field = try #require(situation.field)
        #expect(field.driveStart == 25)
        #expect(field.playStart == 48)
        #expect(field.ball == 82)
        #expect(field.lineToGain == 92)
        #expect(field.isPass)
        #expect(situation.driveLine == "2 plays, 57 yds")
        #expect(situation.lastPlayId == "2")
    }

    @Test func homeDriveReadsRightToLeft() throws {
        let drive = Drive(id: "d", teamId: washington.id, result: nil, isScore: false, summary: nil,
                          period: 2, plays: [snap(id: "1", from: 80, to: 74, distance: 4)])
        let field = try #require(summary(current: drive).situation?.field)
        #expect(field.driveStart == 80)
        #expect(field.ball == 74)
        #expect(field.lineToGain == 70)
    }

    @Test func goalToGoHasNoLineToGain() throws {
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false, summary: nil,
                          period: 2, plays: [snap(id: "1", from: 18, to: 7, distance: 7)])
        #expect(try #require(summary(current: drive).situation?.field).lineToGain == nil)
    }

    /// A sack is the one pass play that stays on the ground.
    @Test func aSackIsNotAPass() throws {
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false, summary: nil,
                          period: 2, plays: [snap(id: "1", from: 47, to: 52, type: "Sack")])
        #expect(try #require(summary(current: drive).situation?.field).isPass == false)
    }

    /// The extra point is the drive's last scoring play, but nobody calls
    /// the drive that.
    @Test func aTouchdownDriveIsATouchdownAfterTheExtraPoint() throws {
        var td = snap(id: "1", from: 7, to: 0, type: "Passing Touchdown", distance: nil, scoring: true)
        td.scoringSide = .away
        var pat = snap(id: "2", from: 3, to: 3, type: "Extra Point Good", distance: nil, scoring: true)
        pat.scoringSide = .away
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false, summary: nil,
                          period: 2, plays: [td, pat])
        let situation = try #require(summary(current: drive).situation)
        #expect(situation.result == "Touchdown")
        #expect(situation.resultTeamId == wsu.id)
        #expect(situation.field?.lineToGain == nil)
    }

    /// A pick six scores for the defense, so the header's logo is theirs.
    @Test func aDefensiveScoreBelongsToTheDefense() throws {
        var pick = snap(id: "1", from: 40, to: 40, type: "Interception Return Touchdown",
                        distance: nil, scoring: true)
        pick.scoringSide = .home
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false, summary: nil,
                          period: 2, plays: [pick])
        #expect(summary(current: drive).situation?.resultTeamId == washington.id)
    }

    @Test func aDriveWithoutTotalsFallsBackToESPNsLine() {
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false,
                          summary: "1 play, 6 yards, 0:05", period: 2)
        #expect(GameSummary.driveLine(drive) == "1 play, 6 yards, 0:05")
        let one = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false, summary: nil,
                        period: 2, offensivePlays: 1, yards: 1)
        #expect(GameSummary.driveLine(one) == "1 play, 1 yd")
    }
}

/// The end zones take the team's color unless it would vanish.
@Suite struct FieldColorTests {
    @Test func aPrimaryColorIsUsedAsIs() {
        #expect(FieldColors.endZoneHex(primary: "970310", alternate: "ffffff", isDark: false) == "970310")
        #expect(FieldColors.endZoneHex(primary: "970310", alternate: "ffffff", isDark: true) == "970310")
    }

    @Test func blackFallsBackToTheAlternateInDarkMode() {
        #expect(FieldColors.endZoneHex(primary: "000000", alternate: "ffcd00", isDark: true) == "ffcd00")
        #expect(FieldColors.endZoneHex(primary: "000000", alternate: "ffcd00", isDark: false) == "000000")
    }

    @Test func whiteFallsBackToTheAlternateInLightMode() {
        #expect(FieldColors.endZoneHex(primary: "ffffff", alternate: "002244", isDark: false) == "002244")
    }

    @Test func nothingUsableMeansGray() {
        #expect(FieldColors.endZoneHex(primary: nil, alternate: nil, isDark: false) == nil)
        #expect(FieldColors.endZoneHex(primary: "zzz", alternate: nil, isDark: false) == nil)
        #expect(FieldColors.endZoneHex(primary: "000000", alternate: "000000", isDark: true) == nil)
    }
}

@MainActor
@Suite struct GamecastCardAccessibilityTests {
    @Test func aScoredDriveSpeaksTheScorer() throws {
        var td = play(id: "1", text: "Shotgun #11 pass complete short middle to #3 for 7 yards, TOUCHDOWN",
                      yardsToEndzone: 0, type: "Passing Touchdown", scoring: true, away: 6, home: 10)
        td.scoringSide = .away
        let drive = Drive(id: "d", teamId: wsu.id, result: nil, isScore: false, summary: nil,
                          period: 2, plays: [td])
        let model = summary(current: drive)
        let card = LiveSituationCard(summary: model, situation: try #require(model.situation))
        #expect(card.accessibilitySummary ==
                "Washington State touchdown, Shotgun #11 pass complete short middle to #3 for 7 yards, TOUCHDOWN")
    }
}

/// The Plays tab's drive rows (2026-09-27): the score a drive left, and a
/// title for the one still being played.
@MainActor
@Suite struct DriveRowTests {
    private func list(_ model: GameSummary) -> PlayByPlayList {
        PlayByPlayList(summary: model, scoringOnly: false)
    }

    @Test func aScoringDriveSpeaksTheScoreItLeft() {
        var td = play(id: "td", text: "pass for 7 yards, TOUCHDOWN", type: "Passing Touchdown",
                      scoring: true, away: 7, home: 10)
        td.scoringSide = .away
        let drive = Drive(id: "d", teamId: wsu.id, result: "Touchdown", isScore: true,
                          summary: nil, period: 2, plays: [td],
                          offensivePlays: 10, yards: 79, timeElapsed: "5:16")
        #expect(drive.runningScore?.away == 7)
        #expect(drive.runningScore?.side == .away)
        #expect(list(summary(current: nil)).accessibilitySummary(for: drive) ==
                "Washington State, touchdown, Washington State 7, Washington 10, 10 plays, 79 yards, 5:16")
    }

    @Test func aDriveThatDidntScoreHasNoScore() {
        let drive = Drive(id: "d", teamId: wsu.id, result: "Punt", isScore: false,
                          summary: nil, period: 2, plays: [play()])
        #expect(drive.runningScore == nil)
    }

    /// ESPN has no result for a drive still being played, so the row said
    /// "—" at the top of every live list.
    @Test func theDriveInProgressSaysWhereThingsStand() {
        let drive = Drive(id: "now", teamId: wsu.id, result: nil, isScore: false,
                          summary: nil, period: 2, plays: [play(yardsToEndzone: 74)])
        let model = summary(current: drive)
        #expect(list(model).title(for: drive) == "2nd & 4 · WSU 26")
        #expect(list(model).accessibilitySummary(for: drive) ==
                "Washington State, in progress, 2nd & 4, WSU 26")
    }

    @Test func aFinishedDriveWithNoResultStillReadsAsADash() {
        let old = Drive(id: "old", teamId: wsu.id, result: nil, isScore: false,
                        summary: nil, period: 1)
        #expect(list(summary(current: nil)).title(for: old) == "—")
    }
}
