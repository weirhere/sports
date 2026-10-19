import SwiftUI

/// The game page's header while it is still on the page: both marks at
/// 44pt with the matchup's headline between them — the score once there
/// is one, the kickoff time before, the status beneath (FotMob's
/// full-time layout; Andy's Paper pass, 2026-10-02). It scrolls away
/// under the bar, where `CompactGameHeader` takes over with the same
/// facts at the bar's scale.
///
/// Its own view since 2026-10-19 (it was `GameDetailScreen.header`), so
/// the snapshot suite can render it from a `Game` with no screen, store
/// or network behind it. `init(game:summary:)` is the only way the screen
/// builds one; the memberwise fields are there for that init and the
/// tests.
struct GameHeader: View {
    typealias Side = (team: Team, score: Int?, record: String?, winner: Bool?)

    let away: Side
    let home: Side
    let isLive: Bool
    let showsScores: Bool
    /// Pre-game only: the kickoff time and its date, rendered as two lines.
    let kickoff: (time: String, date: String?)?
    let statusLine: String
    /// What VoiceOver hears where the header shows its status — the split
    /// kickoff read back as one sentence.
    let statusSpoken: String
    /// The "where do I watch" line — live, or pre-game. Nil once the game
    /// is final, when there is nothing left to tune into.
    let broadcast: String?
    let possessionTeamId: String?
    let glyph: String

    private static let logoSize: CGFloat = 44

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            headerSide(away, outerEdge: .leading)
            VStack(spacing: Spacing.xs) {
                // The merge, not the pushed snapshot: `game` is frozen at
                // push, so a game that ends while its detail is open would
                // keep a pulsing dot above the word "Final".
                if isLive { LiveDot() }
                // With scores in play the matchup's number is the page's
                // headline: one big centered score between the logos
                // (FotMob's full-time layout), status demoted beneath it.
                if showsScores, let awayScore = away.score, let homeScore = home.score {
                    scoreLine(away: awayScore, home: homeScore)
                }
                // Before kickoff the time IS the headline — it takes the
                // slot the score takes once there is one, with the date as
                // its caption rather than a phrase joined on with "at".
                if let kickoff {
                    Text(kickoff.time)
                        .font(.kickoffHero)
                        .foregroundStyle(.textPrimary)
                        // Same reason the score line keeps its intrinsic
                        // width: the equal-thirds header would wrap it.
                        .fixedSize()
                    if let date = kickoff.date {
                        Text(date)
                            .font(.teamName)
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text(statusLine)
                        .font(.metaEmphasis)
                        .foregroundStyle(showsScores ? .textSecondary : .textPrimary)
                        .multilineTextAlignment(.center)
                        // With no score and no kickoff ("Postponed") the
                        // status is all the middle has, and it centers on
                        // the logos rather than hanging off the top of the
                        // row. A frame rather than a padding so it stays
                        // centered at every text size.
                        .frame(minHeight: hasScoreLine ? nil : Self.logoSize)
                }
                // Live is the one state with no other network surface —
                // pre-game has the info card, finals have nothing left to
                // tune into. Detail screen only: the share card's status
                // stays score-shaped.
                if let broadcast {
                    Text(broadcast)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, showsScores ? 0 : Spacing.sm)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                ([statusSpoken]
                    + (broadcast.map { ["on \($0)"] } ?? []))
                    .joined(separator: ", "))
            headerSide(home, outerEdge: .trailing)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
    }

    /// The centered "24 – 17", semibold and in ink in every state (Andy's
    /// Paper pass, 2026-10-02). The winner reads from its semibold name,
    /// and a live game from its dot and clock, not from the numbers.
    private func scoreLine(away: Int, home: Int) -> some View {
        Text("\(away) – \(home)")
            .foregroundStyle(Color.textPrimary)
            .font(.scoreHero)
            // The equal-thirds header would wrap this line; let it keep its
            // intrinsic width and the flexible sides absorb the difference.
            .fixedSize()
    }

    private var hasScoreLine: Bool {
        showsScores && away.score != nil && home.score != nil
    }

    private func hasPossession(_ team: Team) -> Bool {
        possessionTeamId != nil && possessionTeamId == team.id
    }

    /// `Spacing.sm` clear of the logo's `outside` edge. A zero-width frame
    /// pinned to that edge, with the mark hanging off it outward, rather
    /// than alignment guides: a pair of guides on one view read each
    /// other's values and left the mark inside the logo.
    private func possessionMark(outside edge: HorizontalEdge) -> some View {
        Image(systemName: glyph)
            .font(.system(size: 9))
            .foregroundStyle(.textSecondary)
            .padding(edge == .leading ? .trailing : .leading, Spacing.sm)
            .fixedSize()
            .frame(width: 0, alignment: edge == .leading ? .trailing : .leading)
    }

    /// `outerEdge` is the side of the header this team sits on: `.leading`
    /// for away, `.trailing` for home.
    private func headerSide(_ side: Side, outerEdge: HorizontalEdge) -> some View {
        // Value-based so the push lands in the Scores stack's NavigationPath;
        // ScoresScreen owns the matching Team destination.
        NavigationLink(value: side.team) {
            VStack(spacing: Spacing.xs) {
                LogoImage(url: side.team.logoURL)
                    .frame(width: Self.logoSize, height: Self.logoSize)
                    // The scoreboard row's possession mark, at the header's
                    // scale, on the logo's outer side: left of the away
                    // logo, right of the home one. An overlay rather than
                    // an HStack sibling, so the logo stays centered in its
                    // column and the two sides still mirror each other.
                    // It sat off the name until 2026-10-02, where a wrapped
                    // name ("Central Michigan") ran into it.
                    .overlay(alignment: outerEdge == .leading ? .leading : .trailing) {
                        if hasPossession(side.team) {
                            possessionMark(outside: outerEdge)
                        }
                    }
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
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(sideAccessibilityLabel(side))
        }
        .buttonStyle(.plain)
    }

    /// Internal for AccessibilityLabelTests.
    func sideAccessibilityLabel(_ side: Side) -> String {
        let ball = hasPossession(side.team) ? ", has the ball" : ""
        guard showsScores, let score = side.score else { return side.team.location + ball }
        return "\(side.team.location) \(score)\(ball)"
    }
}

extension GameHeader {
    /// Every field from the merge, the way the detail screen builds it:
    /// the scoreboard's `Game` immediately, the (maybe-nil) fresher
    /// summary filling in. Delegated to `GameHeaderState` so the share
    /// card provably renders the same merge and status strings.
    init(game: Game, summary: GameSummary?) {
        let kickoff = GameHeaderState.kickoff(game, summary)
        let isLive = GameHeaderState.isLive(game, summary)
        let statusLine = GameHeaderState.statusLine(game, summary)
        let spoken: String = if let kickoff {
            [kickoff.date, kickoff.time].compactMap { $0 }.joined(separator: ", ")
        } else {
            statusLine.replacingOccurrences(of: "\n", with: ", ")
        }
        self.init(away: GameHeaderState.competitor(game.away, summary?.away),
                  home: GameHeaderState.competitor(game.home, summary?.home),
                  isLive: isLive,
                  showsScores: GameHeaderState.showsScores(game, summary),
                  kickoff: kickoff,
                  statusLine: statusLine,
                  statusSpoken: spoken,
                  // Gated on the summary-fresher status so it retires the
                  // moment the game goes final.
                  broadcast: (isLive || kickoff != nil) ? game.broadcast : nil,
                  possessionTeamId: GameHeaderState.possessionTeamId(game, summary),
                  glyph: game.home.team.league.fallbackGlyph)
    }
}

extension CompactGameHeader {
    /// The bar's scoreboard from the same merge as `GameHeader`: the
    /// kickoff time where the full header has one, the score with its
    /// clock or dash where it has a score line, and the bare status
    /// ("Postponed") otherwise.
    init(game: Game, summary: GameSummary?) {
        let away = GameHeaderState.competitor(game.away, summary?.away)
        let home = GameHeaderState.competitor(game.home, summary?.home)
        let isLive = GameHeaderState.isLive(game, summary)
        let status = GameHeaderState.statusLine(game, summary).replacingOccurrences(of: "\n", with: " ")
        let middle: Middle
        if let kickoff = GameHeaderState.kickoff(game, summary) {
            middle = .kickoff(kickoff.time)
        } else if GameHeaderState.showsScores(game, summary),
                  let awayScore = away.score, let homeScore = home.score {
            middle = .score(away: awayScore, home: homeScore, status: status, isLive: isLive)
        } else {
            middle = .status(status)
        }
        self.init(away: away, home: home, middle: middle,
                  possessionTeamId: GameHeaderState.possessionTeamId(game, summary),
                  glyph: game.home.team.league.fallbackGlyph)
    }
}
