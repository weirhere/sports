import SwiftUI

/// Chronological scoring plays with quarter markers. Every row says whose
/// score it was, twice over: the team's mark leads the row, and that
/// side's number carries the weight in the running score.
struct ScoringPlaysList: View {
    let summary: GameSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var markerWidth: CGFloat = 40
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 16

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        // The card's CardHeader names the section now; this view is just
        // the rows.
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(summary.scoringPlays.enumerated()), id: \.element.id) { index, play in
                if periodMarker(at: index) {
                    Text(PeriodLabel.text(play.period))
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, index == 0 ? 0 : Spacing.sm)
                        .padding(.bottom, Spacing.xs)
                }
                playRow(play)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.sm)
    }

    private func periodMarker(at index: Int) -> Bool {
        index == 0 || summary.scoringPlays[index].period != summary.scoringPlays[index - 1].period
    }

    /// At accessibility sizes the play text takes the full width on its own
    /// line; the narrow type/clock gutter can't survive beside it. The mark
    /// rides the first line either way.
    @ViewBuilder
    private func playRow(_ play: ScoringPlay) -> some View {
        let content = Group {
            if isStacked {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        teamMark(play)
                        typeText(play)
                        clockText(play)
                        Spacer(minLength: Spacing.sm)
                        scoreText(play)
                    }
                    playText(play)
                }
            } else {
                // sm rather than md between the columns: the mark is new
                // width, and the play text is what should keep it.
                HStack(alignment: .top, spacing: Spacing.sm) {
                    teamMark(play)
                    VStack(alignment: .leading, spacing: 2) {
                        typeText(play)
                        clockText(play)
                    }
                    .frame(minWidth: markerWidth, alignment: .leading)
                    playText(play)
                    Spacer(minLength: Spacing.sm)
                    scoreText(play)
                }
            }
        }
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary(for: play))
    }

    /// The scoring team's mark. A `teamId` that resolves to neither side
    /// (CFBD's school-name join can miss) leaves the slot empty rather
    /// than holding a placeholder disc in the gutter.
    private func teamMark(_ play: ScoringPlay) -> some View {
        LogoImage(url: summary.team(withId: play.teamId)?.logoURL, placeholder: nil)
            .frame(width: logoSize, height: logoSize)
    }

    private func typeText(_ play: ScoringPlay) -> some View {
        Text(play.typeAbbreviation ?? "–")
            .font(.metaEmphasis)
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
    }

    @ViewBuilder
    private func clockText(_ play: ScoringPlay) -> some View {
        if let clock = play.clock {
            Text(clock)
                .font(.meta.monospacedDigit())
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                // "7:03" is narrower than the gutter at default sizes and
                // wider at accessibility ones — pin it so it never breaks
                // into "7:" over "03".
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func playText(_ play: ScoringPlay) -> some View {
        Text(play.text ?? "")
            .font(.meta)
            .foregroundStyle(.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The running score, with the side that just scored carrying the
    /// weight. This is the signal that survives an unfamiliar mark — and
    /// it's weight, not color, so the budget holds.
    @ViewBuilder
    private func scoreText(_ play: ScoringPlay) -> some View {
        if let away = play.awayScore, let home = play.homeScore {
            let scorer = scoringSide(play)
            (number(away, emphasized: scorer == .away)
             + Text("–").font(.meta).foregroundStyle(Color.textSecondary)
             + number(home, emphasized: scorer == .home))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func number(_ value: Int, emphasized: Bool) -> Text {
        Text("\(value)")
            .font((emphasized ? Font.metaEmphasis : .meta).monospacedDigit())
            .foregroundStyle(emphasized ? Color.textPrimary : Color.textSecondary)
    }

    private enum Side { case away, home }

    /// Which side's number to emphasize. Nil for a play whose team we
    /// can't place — then neither number is emphasized and the row reads
    /// exactly as it did before the mark existed.
    private func scoringSide(_ play: ScoringPlay) -> Side? {
        guard let teamId = play.teamId else { return nil }
        if teamId == summary.away?.team.id { return .away }
        if teamId == summary.home?.team.id { return .home }
        return nil
    }

    /// One spoken sentence: "Indiana, Fernando Mendoza 18 Yd pass,
    /// Miami 0, Indiana 7". VoiceOver had the same problem the sighted
    /// row did — it never named a team.
    /// Internal, not private, so the label shape is unit-testable.
    func accessibilitySummary(for play: ScoringPlay) -> String {
        var parts: [String] = []
        if let scorer = summary.team(withId: play.teamId)?.location { parts.append(scorer) }
        if let text = play.text, !text.isEmpty { parts.append(text) }
        if let away = play.awayScore, let home = play.homeScore {
            let awayName = summary.away?.team.location ?? "Away"
            let homeName = summary.home?.team.location ?? "Home"
            parts.append("\(awayName) \(away), \(homeName) \(home)")
        }
        return parts.joined(separator: ", ")
    }
}
