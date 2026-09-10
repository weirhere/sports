#if DEBUG
import SwiftUI

#if canImport(ActivityKit)
import ActivityKit

/// A DEBUG-only harness for looking at the Live Activity on a real lock
/// screen, one state at a time.
///
/// It exists because the card can't otherwise be seen: path 3's broadcast
/// service doesn't exist yet, `LiveActivityController.isAvailable` is
/// false, and there is no production entry point. Same precedent as
/// `FixtureScoresClient` — a scripted backend that never reaches a release
/// build, because the real thing can't be scheduled for a review session.
///
/// Reached by long-pressing the wordmark on Scores.
struct LiveActivityDebugSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var controller = LiveActivityController()
    @State private var note = ""

    private var isRunning: Bool { controller.isActive(gameId: DebugGame.id) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Activities enabled",
                                   value: controller.areActivitiesEnabled ? "Yes" : "No")
                    LabeledContent("Card on screen", value: isRunning ? "Yes" : "No")
                    if !note.isEmpty {
                        Text(note).font(.meta).foregroundStyle(.textSecondary)
                    }
                } header: {
                    Text("State")
                } footer: {
                    Text("Lock the simulator (⌘L) to see the card. Long-press the "
                         + "Dynamic Island for the expanded state.")
                }

                Section("Start") {
                    button("Pre-game", "clock") {
                        await start(DebugGame.preGame)
                    }
                }

                Section("Move it") {
                    button("Live — Q3 5:24", "dot.radiowaves.left.and.right") {
                        await update(DebugGame.live, summary: DebugGame.liveSummary)
                    }
                    button("Halftime", "pause.circle") {
                        await update(DebugGame.halftime)
                    }
                    button("Final", "flag.checkered") {
                        await update(DebugGame.final)
                    }
                    button("Force stale", "exclamationmark.triangle") {
                        await controller.debugMakeStale(gameId: DebugGame.id)
                        note = "Backdated the stale deadline — the clock should lose its green."
                    }
                }

                Section {
                    button("End the activity", "xmark.circle", role: .destructive) {
                        await controller.end(gameId: DebugGame.id)
                        note = ""
                    }
                }
            }
            .navigationTitle("Live Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func button(_ title: String, _ icon: String,
                        role: ButtonRole? = nil,
                        action: @escaping () async -> Void) -> some View {
        Button(role: role) {
            Task { await action() }
        } label: {
            Label(title, systemImage: icon)
        }
    }

    private func start(_ game: Game) async {
        guard controller.areActivitiesEnabled else {
            note = "Live Activities are off for StatSide in Settings."
            return
        }
        let started = await controller.start(game: game)
        note = started
            ? "Started. Lock the screen to see it."
            : (isRunning ? "Already running — use Move it." : "Request failed; check the console.")
    }

    private func update(_ game: Game, summary: GameSummary? = nil) async {
        guard isRunning else {
            note = "Nothing running — start the pre-game card first."
            return
        }
        await controller.update(game: game, summary: summary)
        note = ""
    }
}

/// One synthetic matchup, with real ESPN marks so the logo path is
/// exercised rather than stubbed — the byte cache, the `500-dark` variant
/// and the placeholder fallback all behave as they will in production.
private enum DebugGame {
    static let id = "debug-activity"
    private static let awayId = "333"   // Alabama
    private static let homeId = "61"    // Georgia

    private static func team(_ id: String, _ location: String, _ abbreviation: String) -> Team {
        Team(id: id, location: location, name: nil, abbreviation: abbreviation,
             displayName: nil, shortDisplayName: nil,
             logoURL: URL(string: "https://a.espncdn.com/i/teamlogos/ncaa/500/\(id).png"),
             conferenceId: nil)
    }

    private static func game(_ status: GameStatus,
                             away: Int?, home: Int?,
                             date: Date?) -> Game {
        Game(id: id, date: date, name: nil, shortName: nil, weekNumber: 5, status: status,
             home: Competitor(team: team(homeId, "Georgia", "UGA"), score: home,
                              record: "3-0", rank: 2, isHome: true, winner: nil),
             away: Competitor(team: team(awayId, "Alabama", "ALA"), score: away,
                              record: "2-1", rank: 11, isHome: false, winner: nil),
             broadcast: "ABC")
    }

    static var preGame: Game {
        game(.pre(detail: nil), away: nil, home: nil,
             date: Date().addingTimeInterval(2 * 60 * 60))
    }

    private static let liveStatus = GameStatus.live(
        displayClock: "5:24", period: 3, detail: nil, phase: .playing, possessionTeamId: homeId)

    static var live: Game { game(liveStatus, away: 7, home: 24, date: .now) }

    static var halftime: Game {
        game(.live(displayClock: "0:00", period: 2, detail: nil,
                   phase: .halftime, possessionTeamId: nil),
             away: 7, home: 17, date: .now)
    }

    static var final: Game {
        game(.final(detail: "Final"), away: 10, home: 38, date: .now)
    }

    /// Gives the live card its second line. `situation` derives from
    /// `drives.current`, so a drive with one play on it is the smallest
    /// thing that produces "3rd & 7 · UGA ball".
    static var liveSummary: GameSummary {
        let play = Play(id: "p1",
                        text: "Pass short right to #3 for 3 yards",
                        downDistanceText: "2nd & 10 at UGA 39",
                        nextDownDistanceText: "3rd & 7",
                        possessionText: "UGA 42",
                        yardsToEndzone: 58,
                        clock: "5:24", period: 3, typeText: "Pass Reception",
                        isScoringPlay: false, awayScore: 7, homeScore: 24)
        let drive = Drive(id: "d1", teamId: homeId, result: nil, isScore: false,
                          summary: "4 plays, 21 yards, 1:48", period: 3, plays: [play])
        return GameSummary(home: nil, away: nil, status: liveStatus,
                           scoringPlays: [], drives: [], currentDrive: drive,
                           teamStats: [], leaders: [], venue: nil, attendance: nil)
    }
}
#endif
#endif
