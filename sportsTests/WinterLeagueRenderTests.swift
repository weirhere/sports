import SwiftUI
import XCTest
@testable import StatSide

private final class WinterRenderToken {}

/// Not a test of behavior — a camera. Renders the surfaces basketball and
/// hockey changed, from the live fixtures, so the shapes can be reviewed
/// without waiting for a season to start.
@MainActor
final class WinterLeagueRenderTests: XCTestCase {

    /// Where the PNGs land for eyeballing outside Xcode. Set
    /// `WINTER_RENDER_DIR` to a directory to keep copies; otherwise this
    /// only attaches them to the result bundle.
    private var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["WINTER_RENDER_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    func testRenderWinterSurfaces() throws {
        let nba = try summary("nba-summary", league: .nba)
        let nhl = try summary("nhl-summary", league: .nhl)
        let nbaStandings = try standings("nba-standings", league: .nba)
        let nhlStandings = try standings("nhl-standings", league: .nhl)

        try render(name: "nba-line-score", width: 393) {
            captioned("NBA — LINE SCORE (quarters)") {
                LineScoreGrid(summary: nba, league: .nba)
            }
        }
        try render(name: "nhl-line-score", width: 393) {
            captioned("NHL — LINE SCORE (periods, OT, shootout)") {
                LineScoreGrid(summary: nhl, league: .nhl, allowsShootout: true)
            }
        }
        try render(name: "nba-standings", width: 393) {
            captioned("NBA — W-L / PCT / GB") {
                standingsTable(nbaStandings, league: .nba)
            }
        }
        try render(name: "nhl-standings", width: 393) {
            captioned("NHL — GP / W-L-OTL / PTS") {
                standingsTable(nhlStandings, league: .nhl)
            }
        }
        try render(name: "nhl-goals", width: 393) {
            captioned("NHL — GOALS (derived from the play feed)") {
                ScoringPlaysList(summary: nhl, league: .nhl, allowsShootout: true)
            }
        }
        try render(name: "nba-plays", width: 393) {
            captioned("NBA — PLAYS BY PERIOD") {
                PeriodPlayList(summary: nba, league: .nba, scoringOnly: false)
            }
        }
        try render(name: "nba-leaders", width: 393) {
            captioned("NBA — LEADERS") { LeadersList(summary: nba) }
        }
        try render(name: "nhl-team-stats", width: 393) {
            captioned("NHL — TEAM STATS") { TeamStatsCompare(summary: nhl) }
        }

        // The Tables hub's accordion, now that it lists divisions rather
        // than conferences (Andy, 2026-09-09).
        for (name, league, caption) in [("nba-standings-level3", League.nba, "NBA"),
                                        ("nhl-standings-level3", .nhl, "NHL")] {
            let divisions = try divisionTables(name, league: league)
            let leagueTable = divisions.foldingDivisions().leagueTable(in: league)
            try render(name: "\(league.rawValue)-hub-rows", width: 393) {
                captioned("\(caption) — HUB ACCORDION (league, then divisions)") {
                    // No NavigationStack: ImageRenderer lays out none of
                    // its content. The rows' links still draw their labels.
                    VStack(spacing: 0) {
                        if let leagueTable {
                            ConferenceListRow(conference: leagueTable)
                        }
                        ForEach(divisions) { ConferenceListRow(conference: $0) }
                    }
                    // The follow star reads the store from the
                    // environment, so the rows need one to render at all.
                    .environment(FollowingStore(defaults: Self.scratchDefaults))
                }
            }
        }
    }

    /// The court and rink Gamecast (2026-09-27), from the finals cut off
    /// mid-game, since no live game exists to point a camera at. The card
    /// itself doesn't gate on live; the screen does.
    func testRenderGamecastCards() throws {
        var nba = try summary("nba-summary", league: .nba)
        nba.plays = nba.plays.filter { ($0.period ?? 0) <= 2 }
        var nhl = try summary("nhl-summary", league: .nhl)
        let second = nhl.plays.filter { $0.period == 2 }
        nhl.plays = nhl.plays.filter { ($0.period ?? 0) < 2 } + second.prefix(second.count * 3 / 5)

        // Football's card after the refactor, from a real drive: the
        // final's last drive with plays, promoted to the current one.
        var football = try summary("summary-final-live", league: .collegeFootball)
        football.currentDrive = football.drives.last { drive in
            drive.plays.count > 2 && drive.plays.last?.yardsToEndzone != nil
        }
        let situation = try XCTUnwrap(football.situation)
        try render(name: "cfb-gamecast-light", width: 393) {
            captioned("CFB — GAMECAST") {
                LiveSituationCard(summary: football, situation: situation)
            }
        }

        for (name, game, league, shootout) in [("nba", nba, League.nba, false),
                                               ("nhl", nhl, .nhl, true)] {
            let map = try XCTUnwrap(ShotMap.current(plays: game.plays, league: league,
                                                    awayId: game.away?.team.id,
                                                    allowsShootout: shootout))
            let content = try XCTUnwrap(GamecastContent.shotMap(summary: game, league: league,
                                                                allowsShootout: shootout))
            for scheme in [ColorScheme.light, .dark] {
                try render(name: "\(name)-gamecast-\(scheme == .dark ? "dark" : "light")", width: 393) {
                    captioned("\(name.uppercased()) — GAMECAST") {
                        LiveSituationCard(summary: game, content: content, map: map)
                    }
                    .environment(\.colorScheme, scheme)
                }
            }
        }
    }

    /// A throwaway suite, so rendering never touches real follows.
    private static let scratchDefaults: UserDefaults = {
        UserDefaults(suiteName: "test.winterrender.\(UUID().uuidString)") ?? .standard
    }()

    /// The hub's own order: grouped by conference, alphabetical inside
    /// it, so the picture matches what ships.
    private func divisionTables(_ name: String, league: League) throws -> [ConferenceStandings] {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
        let conferenceOrder = Conference.topLevelIds(in: league)
        func rank(_ table: ConferenceStandings) -> Int {
            table.parentId.flatMap(conferenceOrder.firstIndex(of:)) ?? conferenceOrder.count
        }
        return ESPNMapper.divisionStandings(from: dto, league: league)
            .sorted { lhs, rhs in
                let (l, r) = (rank(lhs), rank(rhs))
                return l == r ? lhs.name < rhs.name : l < r
            }
    }

    // MARK: - Scaffolding

    private func standingsTable(_ tables: [ConferenceStandings], league: League) -> some View {
        VStack(spacing: 0) {
            StandingsColumnCaptions(league: league)
            ForEach(Array((tables.first?.entries.prefix(6) ?? []).enumerated()),
                    id: \.element.id) { index, entry in
                ConferenceStandingRow(standing: entry, position: index + 1)
            }
        }
    }

    private func captioned(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            content()
                .background(Color.bgCard)
        }
        .padding(.vertical, Spacing.md)
    }

    private func render(name: String, width: CGFloat,
                        @ViewBuilder content: () -> some View) throws {
        let renderer = ImageRenderer(content: content()
            .frame(width: width)
            .background(Color.bgRecessed)
            .environment(\.liveDotPulses, false))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage, "\(name) should render")
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = outputDirectory, let data = image.pngData() {
            try? FileManager.default.createDirectory(at: directory,
                                                     withIntermediateDirectories: true)
            try? data.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: WinterRenderToken.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func summary(_ name: String, league: League) throws -> GameSummary {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture(name))
        return ESPNMapper.gameSummary(from: dto, league: league)
    }

    private func standings(_ name: String, league: League) throws -> [ConferenceStandings] {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
        return ESPNMapper.conferenceStandings(from: dto, league: league)
    }
}
