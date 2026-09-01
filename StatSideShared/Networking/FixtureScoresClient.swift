#if DEBUG
import Foundation

/// A scripted `ScoresProviding` for the live-detail regression tests
/// (BACKLOG E5: an open live game detail popped itself back to Scores on
/// 2026-08-29). Every scoreboard fetch advances a shared tick counter and
/// replays the state changes a real Saturday serves — scores moving,
/// clocks ticking, halftime phases, a pre-game kicking off, a live game
/// going final, a game vanishing from the payload for one fetch, a rank
/// appearing and disappearing, and a transient fetch failure — so a UI
/// test can compress an hour of churn into a minute and hold a pushed
/// detail against it.
///
/// Activated by `-data.provider fixture` (DEBUG builds only, wired in
/// `DataProvider`). Never touches the network.
nonisolated final class FixtureScoresClient: ScoresProviding {
    /// One timeline shared by every instance: the app makes separate
    /// clients for the scoreboard store and each detail screen, and they
    /// must all see the same evolving Saturday.
    private actor SharedState {
        static let shared = SharedState()
        private var tick = 0

        /// The scoreboard's fetch advances the clock; summary fetches read
        /// the current tick without advancing so the detail screen stays
        /// in step with the list.
        func nextTick() -> Int {
            tick += 1
            return tick
        }

        func currentTick() -> Int { tick }
    }

    private static func team(_ id: String, _ location: String, _ abbreviation: String,
                             conferenceId: Int) -> Team {
        Team(id: id, location: location, name: nil, abbreviation: abbreviation,
             displayName: location, shortDisplayName: location,
             logoURL: nil, conferenceId: conferenceId)
    }

    private static let holdAway = team("fx-100", "Alpha State", "ALPH", conferenceId: 8)
    private static let holdHome = team("fx-101", "Bravo Tech", "BRVO", conferenceId: 8)
    private static let fadesAway = team("fx-102", "Charlie A&M", "CHAR", conferenceId: 5)
    private static let fadesHome = team("fx-103", "Delta College", "DELT", conferenceId: 5)
    private static let kicksAway = team("fx-104", "Echo State", "ECHO", conferenceId: 4)
    private static let kicksHome = team("fx-105", "Foxtrot", "FOXT", conferenceId: 4)
    private static let flakyAway = team("fx-106", "Golf Valley", "GOLF", conferenceId: 1)
    private static let flakyHome = team("fx-107", "Hotel Poly", "HOTL", conferenceId: 1)
    /// The FCS half of the scripted Saturday (E8). `fcsVisitor` plays at
    /// an FBS school, so its game ships in BOTH division payloads exactly
    /// as ESPN ships the real 37-game overlap; `fcsHome`/`fcsAway` play
    /// each other, so their game exists only in group 81 and is the thing
    /// a union actually adds.
    private static let fcsVisitor = team("fx-110", "Kilo State", "KILO", conferenceId: 20)
    private static let fcsAway = team("fx-111", "Lima A&M", "LIMA", conferenceId: 21)
    private static let fcsHome = team("fx-112", "Mike College", "MIKE", conferenceId: 21)

    private static let rankedAway = team("fx-108", "India Southern", "INDS", conferenceId: 17)
    private static let rankedHome = team("fx-109", "Juliet Western", "JULW", conferenceId: 17)

    /// The pushed-and-held game: live from the first fetch and it never
    /// ends, so the test can hold its detail as long as it likes.
    static let holdGameId = "fx-hold"

    /// The hold target's row starts with this text; the UI test finds the
    /// row by it before the label starts churning with the score.
    static let holdAwayName = "Alpha State"

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        let tick = await SharedState.shared.nextTick()
        // Staggered latency so responses land mid-render and overlap the
        // detail poll's, the way ESPN's real jitter interleaves them.
        try? await Task.sleep(for: .milliseconds((tick % 4) * 150))
        // The transient-failure beat: ESPN hiccups mid-Saturday, the store
        // keeps last-good games and shows the refresh banner — a structure
        // change in the exact hierarchy under suspicion.
        if tick % 7 == 3 {
            throw URLError(.networkConnectionLost)
        }
        // Merged the same way the real client merges: by event id, FBS
        // copy winning, so the crossover game appears exactly once.
        var games = divisions.contains(.fbs) ? Self.games(at: tick) : []
        if divisions.contains(.fcs) {
            let seen = Set(games.map(\.id))
            games += Self.fcsGames(at: tick).filter { !seen.contains($0.id) }
        }
        return Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 1,
                          weeks: Self.weeks, games: games)
    }

    func rankings() async throws -> [Poll] { [] }

    func fbsConferences() async throws -> [ConferenceTeams] { [] }

    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] { [] }

    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        throw URLError(.unsupportedURL)
    }

    /// The scripted slate, filtered the way the real clients filter it
    /// (either side in the conference). Read at the current tick without
    /// advancing it: ConferencePage fetches a season exactly once and
    /// caches it, so this snapshot is meant to go stale — the page's live
    /// merge against the polling scoreboard is what keeps its rows honest,
    /// and a stub returning nothing hid that whole screen from the
    /// fixture.
    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game] {
        let tick = await SharedState.shared.currentTick()
        return Self.games(at: max(tick, 1)).filter {
            $0.home.team.conferenceId == conferenceId
                || $0.away.team.conferenceId == conferenceId
        }
    }

    func gameSummary(eventId: String) async throws -> GameSummary {
        let tick = await SharedState.shared.currentTick()
        try? await Task.sleep(for: .milliseconds((tick % 3) * 200))
        // The live-flag flicker is scoreboard-only by default: a
        // pre-flavored summary flips the detail's `isLiveNow` false and
        // its poll loop cancels for good (nothing refetches the summary
        // after that), freezing the exact surface these tests hold. That
        // freeze is itself a finding — filed separately. The
        // `fixture.summaryFlicker` default opts a test INTO the frozen-pre
        // state, the configuration the ghost-push repro needs.
        let flickerless = !UserDefaults.standard.bool(forKey: "fixture.summaryFlicker")
        // Both divisions, so pushing the FCS-only game's detail works.
        let all = Self.games(at: max(tick, 1), flickerless: flickerless)
            + Self.fcsGames(at: max(tick, 1))
        guard let game = all.first(where: { $0.id == eventId }) else {
            throw URLError(.resourceUnavailable)
        }
        let away = GameSummary.Side(team: game.away.team, score: game.away.score,
                                    record: game.away.record, rank: game.away.rank,
                                    winner: game.away.winner,
                                    linescores: ["7", "3"])
        let home = GameSummary.Side(team: game.home.team, score: game.home.score,
                                    record: game.home.record, rank: game.home.rank,
                                    winner: game.home.winner,
                                    linescores: ["0", "7"])
        return GameSummary(
            home: home, away: away, status: game.status,
            scoringPlays: [ScoringPlay(id: "fx-play-1", period: 1, clock: "8:12",
                                       text: "12 yd touchdown pass",
                                       typeAbbreviation: "TD", teamId: game.away.team.id,
                                       awayScore: 7, homeScore: 0)],
            drives: [Drive(id: "fx-drive-1", teamId: game.away.team.id,
                           result: "Touchdown", isScore: true,
                           summary: "8 plays, 75 yards, 3:41", period: 1)],
            teamStats: [StatComparison(id: "totalYards", label: "Total yards",
                                       away: "312", home: "287",
                                       awayValue: 312, homeValue: 287)],
            leaders: [LeaderCategory(
                id: "passing", label: "Passing",
                away: .init(name: "A. Passer", statLine: "18/24, 231 yds"),
                home: .init(name: "B. Thrower", statLine: "14/20, 178 yds"))],
            venue: "Fixture Field", attendance: 54_321)
    }

    // MARK: - The scripted Saturday

    private static let weeks: [WeekSlot] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func slot(_ value: Int, offsetDays: Int) -> WeekSlot {
            WeekSlot(label: "Week \(value)", shortLabel: "\(value)",
                     seasonType: 2, value: value,
                     startDate: calendar.date(byAdding: .day, value: offsetDays, to: today),
                     endDate: calendar.date(byAdding: .day, value: offsetDays + 7, to: today))
        }
        return [slot(1, offsetDays: -3), slot(2, offsetDays: 4), slot(3, offsetDays: 11)]
    }()

    /// The group-81 half: the overlap game (also in the FBS payload, same
    /// event id, so a union must dedupe it) and one FCS-vs-FCS game that
    /// only this division carries.
    private static func fcsGames(at tick: Int) -> [Game] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func kick(hour: Int) -> Date {
            calendar.date(byAdding: .hour, value: hour, to: today) ?? today
        }
        return [
            // Same id as the FBS payload's copy — this IS the overlap.
            Game(id: "fx-crossover", date: kick(hour: 13),
                 name: "Kilo State at Bravo Tech", shortName: "KILO @ BRVO",
                 weekNumber: 1, seasonType: 2, status: .pre(detail: nil),
                 home: Competitor(team: holdHome, score: nil, record: "2-0", rank: nil,
                                  isHome: true, winner: nil),
                 away: Competitor(team: fcsVisitor, score: nil, record: "1-1", rank: nil,
                                  isHome: false, winner: nil),
                 broadcast: "FIX5"),
            Game(id: "fx-fcs", date: kick(hour: 14),
                 name: "Lima A&M at Mike College", shortName: "LIMA @ MIKE",
                 weekNumber: 1, seasonType: 2,
                 status: .live(displayClock: "9:03", period: 2, detail: nil,
                               phase: .playing, possessionTeamId: fcsAway.id),
                 home: Competitor(team: fcsHome, score: 7 + tick % 3, record: "1-1",
                                  rank: nil, isHome: true, winner: nil),
                 away: Competitor(team: fcsAway, score: 10, record: "2-0",
                                  rank: nil, isHome: false, winner: nil),
                 broadcast: "FIX6"),
        ]
    }

    private static func games(at tick: Int, flickerless: Bool = false) -> [Game] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func kick(hour: Int) -> Date {
            calendar.date(byAdding: .hour, value: hour, to: today) ?? today
        }

        var games: [Game] = []

        // fx-hold: live (nearly) forever. Clock ticks, score moves every
        // 3rd fetch, every 10th cycle walks halftime → end-of-quarter →
        // playing, and every 11th fetch the payload flickers it to
        // pre-game for one beat — ESPN's live flags really do stutter —
        // which under the Live filter vanishes its row and section
        // entirely for a tick. (fx-kicks is live by then, so the flicker
        // never leaves the slate with zero live games, which would stop
        // the scoreboard poll for good and stall the whole script.)
        let holdPhase: LivePhase = switch tick % 10 {
        case 6: .halftime
        case 7: .endOfPeriod
        default: .playing
        }
        let holdPeriod = min(1 + tick / 12, 4)
        let holdFlickersPre = tick % 11 == 9 && tick > 5 && !flickerless
        games.append(Game(
            id: holdGameId, date: kick(hour: 12), name: "Alpha State at Bravo Tech",
            shortName: "ALPH @ BRVO", weekNumber: 1, seasonType: 2,
            status: holdFlickersPre
                ? .pre(detail: nil)
                : .live(displayClock: String(format: "%d:%02d", 14 - (tick % 15), 59 - (tick * 7) % 60),
                        period: holdPeriod, detail: nil, phase: holdPhase,
                        possessionTeamId: tick % 2 == 0 ? holdAway.id : holdHome.id),
            home: Competitor(team: holdHome, score: holdFlickersPre ? nil : 10 + (tick / 3) * 7,
                             record: "2-0", rank: nil, isHome: true, winner: nil),
            away: Competitor(team: holdAway, score: holdFlickersPre ? nil : 14 + (tick / 3) * 3,
                             record: "1-1", rank: 12, isHome: false, winner: nil),
            broadcast: "FIX1"))

        // fx-fades: live for the first 8 fetches, then final — the
        // "another game just ended" state change.
        let fadesFinal = tick >= 8
        games.append(Game(
            id: "fx-fades", date: kick(hour: 12), name: "Charlie A&M at Delta College",
            shortName: "CHAR @ DELT", weekNumber: 1, seasonType: 2,
            status: fadesFinal
                ? .final(detail: "Final")
                : .live(displayClock: "2:11", period: 4, detail: nil,
                        phase: .playing, possessionTeamId: fadesHome.id),
            home: Competitor(team: fadesHome, score: 31, record: "2-0", rank: nil,
                             isHome: true, winner: fadesFinal ? true : nil),
            away: Competitor(team: fadesAway, score: 17, record: "0-2", rank: nil,
                             isHome: false, winner: fadesFinal ? false : nil),
            broadcast: "FIX2"))

        // fx-kicks: pre-game until fetch 5, then live — flips its row
        // variant and (upstream) the slate's live census.
        let kicked = tick >= 5
        games.append(Game(
            id: "fx-kicks", date: kick(hour: 15), name: "Echo State at Foxtrot",
            shortName: "ECHO @ FOXT", weekNumber: 1, seasonType: 2,
            status: kicked
                ? .live(displayClock: "12:45", period: 1, detail: nil,
                        phase: .playing, possessionTeamId: kicksAway.id)
                : .pre(detail: nil),
            home: Competitor(team: kicksHome, score: kicked ? 0 : nil, record: "1-1",
                             rank: nil, isHome: true, winner: nil),
            away: Competitor(team: kicksAway, score: kicked ? 3 : nil, record: "2-0",
                             rank: nil, isHome: false, winner: nil),
            broadcast: "FIX3"))

        // The FBS side of the crossover: an FCS visitor at an FBS school,
        // shipped in group 80 too. Same event id as the group-81 copy.
        //
        // Its own kickoff hour, deliberately: `ConferenceSlate.groups`
        // sorts by date and Swift's sort isn't stable, so two games
        // sharing a timestamp make row order churn between body
        // evaluations — which is not a thing a real slate does, and it
        // makes any test that reads "the first row" nondeterministic.
        games.append(Game(
            id: "fx-crossover", date: kick(hour: 13), name: "Kilo State at Bravo Tech",
            shortName: "KILO @ BRVO", weekNumber: 1, seasonType: 2,
            status: .pre(detail: nil),
            home: Competitor(team: holdHome, score: nil, record: "2-0", rank: nil,
                             isHome: true, winner: nil),
            away: Competitor(team: fcsVisitor, score: nil, record: "1-1", rank: nil,
                             isHome: false, winner: nil),
            broadcast: "FIX5"))

        // fx-flaky: vanishes from every 5th payload and returns — ESPN
        // drops and re-adds events mid-Saturday.
        if tick % 5 != 2 {
            games.append(Game(
                id: "fx-flaky", date: kick(hour: 16), name: "Golf Valley at Hotel Poly",
                shortName: "GOLF @ HOTL", weekNumber: 1, seasonType: 2,
                status: .pre(detail: nil),
                home: Competitor(team: flakyHome, score: nil, record: "1-1", rank: nil,
                                 isHome: true, winner: nil),
                away: Competitor(team: flakyAway, score: nil, record: "1-1", rank: nil,
                                 isHome: false, winner: nil),
                broadcast: "FIX4"))
        }

        // fx-ranked: the away side's rank blinks in and out every 4th
        // fetch, moving the game in and out of the Top 25 section.
        let ranked = (tick / 4) % 2 == 0
        games.append(Game(
            id: "fx-ranked", date: kick(hour: 19), name: "India Southern at Juliet Western",
            shortName: "INDS @ JULW", weekNumber: 1, seasonType: 2,
            status: .pre(detail: nil),
            home: Competitor(team: rankedHome, score: nil, record: "2-0", rank: nil,
                             isHome: true, winner: nil),
            away: Competitor(team: rankedAway, score: nil, record: "2-0",
                             rank: ranked ? 24 : nil, isHome: false, winner: nil),
            broadcast: "FIX5"))

        return games
    }
}
#endif
