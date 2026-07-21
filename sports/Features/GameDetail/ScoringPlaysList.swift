import SwiftUI

/// Chronological scoring plays with quarter markers.
struct ScoringPlaysList: View {
    let summary: GameSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SCORING")
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
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

    private func playRow(_ play: ScoringPlay) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(play.typeAbbreviation ?? "–")
                    .font(.metaEmphasis)
                    .foregroundStyle(.textPrimary)
                if let clock = play.clock {
                    Text(clock)
                        .font(.meta.monospacedDigit())
                        .foregroundStyle(.textSecondary)
                }
            }
            .frame(width: 40, alignment: .leading)
            Text(play.text ?? "")
                .font(.meta)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.sm)
            if let away = play.awayScore, let home = play.homeScore {
                Text("\(away)–\(home)")
                    .font(.meta.monospacedDigit())
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 5)
    }
}
