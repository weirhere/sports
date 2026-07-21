import SwiftUI
import os

/// Tap a game, land somewhere worth landing: header, linescore, scoring
/// plays, team stats, leaders.
struct GameDetailScreen: View {
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "gamedetail")

    let game: Game

    @Environment(\.scenePhase) private var scenePhase

    @State private var summary: GameSummary?
    @State private var isLoading = false
    @State private var lastError: String?

    private let client: any ScoresProviding = DataProvider.makeClient()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider().overlay(Color.divider)
                if let summary {
                    if summary.away?.linescores.isEmpty == false {
                        LineScoreGrid(summary: summary)
                        Divider().overlay(Color.divider)
                    }
                    if !summary.scoringPlays.isEmpty {
                        ScoringPlaysList(summary: summary)
                        Divider().overlay(Color.divider)
                    }
                    if !summary.teamStats.isEmpty {
                        TeamStatsCompare(summary: summary)
                        Divider().overlay(Color.divider)
                    }
                    if !summary.leaders.isEmpty {
                        LeadersList(summary: summary)
                        Divider().overlay(Color.divider)
                    }
                    if !summary.drives.isEmpty {
                        DriveLogList(summary: summary)
                        Divider().overlay(Color.divider)
                    }
                    footer(summary)
                } else if isLoading {
                    ProgressView().padding(.vertical, Spacing.xl)
                } else if lastError != nil {
                    VStack(spacing: Spacing.sm) {
                        Text("Couldn't load this game.")
                            .font(.teamName)
                            .foregroundStyle(.textSecondary)
                        Button("Retry") {
                            Task { await load(force: true) }
                        }
                        .font(.teamNameEmphasis)
                        .foregroundStyle(.textPrimary)
                    }
                    .padding(.vertical, Spacing.xl)
                }
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle(game.shortName ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        // 30s auto-refresh mirrors the scoreboard's polling rules: only while
        // the scene is active and the game is in progress. The id flips when
        // either condition changes, cancelling or restarting the loop — a
        // summary that comes back final stops it on its own.
        .task(id: scenePhase == .active && isLiveNow) {
            guard scenePhase == .active, isLiveNow else { return }
            Self.logger.info("detail polling: started for event \(game.id)")
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                Self.logger.info("detail polling: tick for event \(game.id)")
                await load(force: true)
            }
            Self.logger.info("detail polling: stopped for event \(game.id)")
        }
        .refreshable { await load(force: true) }
    }

    private var isLiveNow: Bool {
        if case .live = summary?.status ?? game.status { return true }
        return false
    }

    /// Renders from the scoreboard's Game immediately; the summary fills in.
    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            headerSide(competitor(game.away, summary?.away))
            VStack(spacing: Spacing.xs) {
                if game.isLive { LiveDot() }
                Text(statusLine)
                    .font(.metaEmphasis)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.md)
            headerSide(competitor(game.home, summary?.home))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headerAccessibilityLabel)
    }

    private var headerAccessibilityLabel: String {
        let away = competitor(game.away, summary?.away)
        let home = competitor(game.home, summary?.home)
        func side(_ s: (team: Team, score: Int?, record: String?, winner: Bool?)) -> String {
            guard showsScores, let score = s.score else { return s.team.location }
            return "\(s.team.location) \(score)"
        }
        let matchup = showsScores
            ? "\(side(away)), \(side(home))"
            : "\(away.team.location) at \(home.team.location)"
        return "\(matchup), \(statusLine.replacingOccurrences(of: "\n", with: ", "))"
    }

    private func competitor(_ fallback: Competitor, _ side: GameSummary.Side?)
        -> (team: Team, score: Int?, record: String?, winner: Bool?) {
        guard let side else {
            return (fallback.team, fallback.score, fallback.record, fallback.winner)
        }
        return (side.team, side.score, side.record ?? fallback.record, side.winner)
    }

    private func headerSide(_ side: (team: Team, score: Int?, record: String?, winner: Bool?)) -> some View {
        VStack(spacing: Spacing.xs) {
            LogoImage(url: side.team.logoURL)
                .frame(width: 44, height: 44)
            Text(side.team.location)
                .font(side.winner == true ? .teamNameEmphasis : .teamName)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                // Reserved so a wrapping name ("Arkansas-Pine Bluff")
                // doesn't push its record below the other side's.
                .lineLimit(2, reservesSpace: true)
            if let record = side.record {
                Text(record)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
            if showsScores, let score = side.score {
                Text("\(score)")
                    .font(game.isLive ? .scoreLive : .score)
                    .foregroundStyle(side.winner == false ? .textSecondary : .textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var showsScores: Bool {
        if case .pre = summary?.status ?? game.status { return false }
        return true
    }

    private var statusLine: String {
        switch summary?.status ?? game.status {
        case .pre:
            let kick = game.date?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()) ?? "TBD"
            return game.broadcast.map { "\(kick)\n\($0)" } ?? kick
        case .live(let clock, let period, let detail, _):
            let quarter = period.map { $0 <= 4 ? "Q\($0)" : "OT" }
            return [quarter, clock].compactMap(\.self).joined(separator: " ")
                .isEmpty ? (detail ?? "Live") : [quarter, clock].compactMap(\.self).joined(separator: " ")
        case .final(let detail):
            return detail ?? "Final"
        case .other(let detail):
            return detail ?? "—"
        }
    }

    private func footer(_ summary: GameSummary) -> some View {
        VStack(spacing: Spacing.xs) {
            if let venue = summary.venue {
                Text(venue)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
            if let attendance = summary.attendance {
                Text("Attendance \(attendance.formatted())")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(.vertical, Spacing.lg)
    }

    private func load(force: Bool = false) async {
        guard summary == nil || force else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            summary = try await client.gameSummary(eventId: game.id)
            lastError = nil
        } catch {
            lastError = "Couldn't load this game."
        }
    }
}
