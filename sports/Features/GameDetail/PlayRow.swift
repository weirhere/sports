import SwiftUI

/// One play, wherever it is listed — inside a football drive or inside a
/// basketball or hockey period.
///
/// Extracted when the flat play feed arrived rather than copied: the two
/// lists ask the same question of a play and would otherwise answer it
/// differently the first time either changed.
struct PlayRow: View {
    let play: Play
    /// Whose game, for the spoken running score.
    let summary: GameSummary
    /// How far the row indents past its parent's mark, so the plays read
    /// as that drive's or that period's children.
    let indent: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var clockWidth: CGFloat = 40

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, indent)
            .padding(.trailing, Spacing.lg)
            .padding(.vertical, 5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.accessibilitySummary(for: play, in: summary))
    }

    /// The clock sits in the gutter the scoring list uses; the down line
    /// heads the play, and the narration follows it. At accessibility
    /// sizes the gutter can't survive beside the text, so it stacks.
    @ViewBuilder
    private var content: some View {
        if isStacked {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.sm) {
                    clockText
                    leadText
                    Spacer(minLength: Spacing.sm)
                    scoreText
                }
                playText
            }
        } else {
            HStack(alignment: .top, spacing: Spacing.sm) {
                clockText
                    .frame(minWidth: clockWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        leadText
                        Spacer(minLength: Spacing.sm)
                        scoreText
                    }
                    playText
                }
            }
        }
    }

    @ViewBuilder
    private var clockText: some View {
        if let clock = play.clock {
            Text(clock)
                .font(.meta.monospacedDigit())
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    /// "1st & 10 at IU 5" in football, falling back to the play's own type
    /// where ESPN gives no down — kickoffs and extra points, and every
    /// basketball and hockey play, none of which has a down at all.
    @ViewBuilder
    private var leadText: some View {
        if let line = play.downDistanceText ?? play.typeText {
            Text(line)
                .font(.metaEmphasis)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var playText: some View {
        Text(play.text ?? "")
            .font(.meta)
            .foregroundStyle(play.isScoringPlay ? .textPrimary : .textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Only scoring plays carry the running score — every other row would
    /// repeat the number above it. Weight marks the side that scored, the
    /// scoring list's rule, so the budget stays at three colors. A play
    /// the mapper couldn't attribute emphasizes neither number.
    @ViewBuilder
    private var scoreText: some View {
        if play.isScoringPlay, let away = play.awayScore, let home = play.homeScore {
            (Self.number(away, emphasized: play.scoringSide == .away)
             + Text("–").font(.meta).foregroundStyle(Color.textSecondary)
             + Self.number(home, emphasized: play.scoringSide == .home))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private static func number(_ value: Int, emphasized: Bool) -> Text {
        Text("\(value)")
            .font((emphasized ? Font.metaEmphasis : .meta).monospacedDigit())
            .foregroundStyle(emphasized ? Color.textPrimary : Color.textSecondary)
    }

    /// "1st & 10 at IU 5, 12:16, Shotgun #15 F.Mendoza pass complete…" —
    /// the down first, because it's the context the narration assumes.
    /// Static so the label shape is unit-testable without a view.
    static func accessibilitySummary(for play: Play, in summary: GameSummary) -> String {
        var parts: [String] = []
        if let line = play.downDistanceText ?? play.typeText { parts.append(line) }
        if let clock = play.clock { parts.append(clock) }
        if let text = play.text, !text.isEmpty { parts.append(text) }
        if play.isScoringPlay, let away = play.awayScore, let home = play.homeScore {
            let awayName = summary.away?.team.location ?? "Away"
            let homeName = summary.home?.team.location ?? "Home"
            parts.append("\(awayName) \(away), \(homeName) \(home)")
        }
        return parts.joined(separator: ", ")
    }
}
