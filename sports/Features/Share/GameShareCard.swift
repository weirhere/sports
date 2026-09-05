import SwiftUI
import UniformTypeIdentifiers
import os

/// What the detail header derives from a Game plus its (maybe-nil) fresher
/// summary. Extracted so the share card and `GameDetailScreen` render from
/// the same merge and the same status strings — the `ShareSignOff` trick,
/// applied to layout.
nonisolated enum GameHeaderState {
    static func competitor(_ fallback: Competitor, _ side: GameSummary.Side?)
        -> (team: Team, score: Int?, record: String?, winner: Bool?) {
        guard let side else {
            return (fallback.team, fallback.score, fallback.record, fallback.winner)
        }
        return (side.team, side.score, side.record ?? fallback.record, side.winner)
    }

    /// The status the header surfaces render from: the summary's when it
    /// has one, EXCEPT a pre-game summary against a live scoreboard
    /// snapshot. Kickoff doesn't un-happen — that shape is a stale or
    /// flaky summary payload (seen from ESPN mid-Saturday), and honoring
    /// it demoted the live header to pre AND cancelled the detail's poll
    /// loop with nothing left to refetch the summary, freezing the screen
    /// mid-drive. The snapshot's live status wins; the next poll's summary
    /// takes over again.
    static func status(_ game: Game, _ summary: GameSummary?) -> GameStatus {
        guard let status = summary?.status else { return game.status }
        if case .pre = status, case .live = game.status { return game.status }
        return status
    }

    static func showsScores(_ game: Game, _ summary: GameSummary?) -> Bool {
        if case .pre = status(game, summary) { return false }
        return true
    }

    /// Absolute dates only — the share image outlives the moment it was
    /// made, so no "Today"/"Tomorrow" (decision log 2026-08-09).
    static func statusLine(_ game: Game, _ summary: GameSummary?) -> String {
        let merged = status(game, summary)
        switch merged {
        case .pre:
            let style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
            let kick: String = if let date = game.date {
                game.timeTBD ? "\(date.formatted(style)) · TBD" : date.formatted(style.hour().minute())
            } else {
                "TBD"
            }
            return game.broadcast.map { "\(kick)\n\($0)" } ?? kick
        case .live:
            return merged.liveStatusText ?? "Live"
        case .final(let detail):
            return detail ?? "Final"
        case .other(let detail):
            return detail ?? "—"
        }
    }

    static func isLive(_ game: Game, _ summary: GameSummary?) -> Bool {
        if case .live = status(game, summary) { return true }
        return false
    }
}

/// The share payload: a PNG of the matchup card, with the status-shaped
/// text as a fallback for targets that don't take images. Export is lazy —
/// logos fetch and the card renders only when the user picks a share
/// target, so a context menu on a 60-game Saturday costs nothing.
nonisolated struct GameShareCard: Transferable, Sendable {
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "share")

    let game: Game
    let summary: GameSummary?
    /// Already signed off via `ShareSignOff` — the same string the call
    /// site passes to `ShareLink(message:)`.
    let shareText: String

    enum RenderError: Error {
        case imageUnavailable
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            try await card.pngData()
        }
        .suggestedFileName("statside-game.png")

        // Targets that take text but not images (Notes, plain email
        // bodies). Second, so image-capable targets prefer the card.
        ProxyRepresentation(exporting: \.shareText)
    }

    /// Internal, not private: the link-preview item source renders the
    /// same card for `LPLinkMetadata`.
    func pngData() async throws -> Data {
        // LogoCache dedupes in-flight fetches and answers instantly for
        // marks the scoreboard already warmed — the common case. A miss
        // (offline, never-fetched team) degrades to the placeholder disc.
        async let away = logo(summary?.away?.team.logoURL ?? game.away.team.logoURL)
        async let home = logo(summary?.home?.team.logoURL ?? game.home.team.logoURL)
        guard let data = await render(awayLogo: away, homeLogo: home) else {
            Self.logger.error("share card render produced no image for event \(game.id)")
            throw RenderError.imageUnavailable
        }
        return data
    }

    private func logo(_ url: URL?) async -> UIImage? {
        guard let url else { return nil }
        // A cold fetch on a dead network would otherwise hold the share
        // sheet to URLSession's 60 s timeout. Past the budget the card
        // ships with the placeholder disc instead of making anyone wait.
        return await withTaskGroup(of: UIImage?.self) { group in
            group.addTask { await LogoCache.shared.image(for: url) }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(1200))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    @MainActor
    private func render(awayLogo: UIImage?, homeLogo: UIImage?) -> Data? {
        let renderer = ImageRenderer(content: cardView(awayLogo: awayLogo, homeLogo: homeLogo)
            .frame(width: 600)
            // Always light: the recipient sees the same card whatever the
            // sharer's appearance, and it reads on any thread background.
            .environment(\.colorScheme, .light))
        // Fixed, not screen-derived — the same artifact from every device.
        renderer.scale = 3
        // Opaque so the white card can't arrive as alpha over a dark thread.
        renderer.isOpaque = true
        return renderer.uiImage?.pngData()
    }

    @MainActor
    private func cardView(awayLogo: UIImage?, homeLogo: UIImage?) -> GameShareCardView {
        let away = GameHeaderState.competitor(game.away, summary?.away)
        let home = GameHeaderState.competitor(game.home, summary?.home)
        return GameShareCardView(
            away: .init(name: away.team.location, record: away.record, score: away.score,
                        rank: summary?.away?.rank ?? game.away.rank, winner: away.winner, logo: awayLogo),
            home: .init(name: home.team.location, record: home.record, score: home.score,
                        rank: summary?.home?.rank ?? game.home.rank, winner: home.winner, logo: homeLogo),
            statusLine: GameHeaderState.statusLine(game, summary),
            showsScores: GameHeaderState.showsScores(game, summary),
            isLive: GameHeaderState.isLive(game, summary))
    }
}
