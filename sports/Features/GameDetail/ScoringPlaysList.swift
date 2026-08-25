import SwiftUI

/// Chronological scoring plays with quarter markers.
struct ScoringPlaysList: View {
    let summary: GameSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var markerWidth: CGFloat = 40

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        // The card's CardHeader names the section now; this view is just
        // the rows.
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(summary.scoringPlays.enumerated()), id: \.element.id) { index, play in
                if periodMarker(at: index) {
                    Text(periodLabel(play.period))
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

    private func periodLabel(_ period: Int?) -> String {
        guard let period else { return "—" }
        switch period {
        case 1: return "1ST QUARTER"
        case 2: return "2ND QUARTER"
        case 3: return "3RD QUARTER"
        case 4: return "4TH QUARTER"
        case 5: return "OVERTIME"
        default: return "\(period - 4)OT"
        }
    }

    /// At accessibility sizes the play text takes the full width on its own
    /// line; the narrow type/clock gutter can't survive beside it.
    @ViewBuilder
    private func playRow(_ play: ScoringPlay) -> some View {
        let content = Group {
            if isStacked {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        typeText(play)
                        clockText(play)
                        Spacer(minLength: Spacing.sm)
                        scoreText(play)
                    }
                    playText(play)
                }
            } else {
                HStack(alignment: .top, spacing: Spacing.md) {
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

    @ViewBuilder
    private func scoreText(_ play: ScoringPlay) -> some View {
        if let away = play.awayScore, let home = play.homeScore {
            Text("\(away)–\(home)")
                .font(.meta.monospacedDigit())
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
