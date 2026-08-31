import SwiftUI

/// Per-quarter line score, including OT columns when present.
struct LineScoreGrid: View {
    let summary: GameSummary

    var body: some View {
        Grid(horizontalSpacing: Spacing.lg, verticalSpacing: Spacing.sm) {
            GridRow {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gridColumnAlignment(.leading)
                ForEach(periodLabels, id: \.self) { label in
                    Text(label)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .gridColumnAlignment(.trailing)
                }
                Text("T")
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
                    .gridColumnAlignment(.trailing)
            }
            if let away = summary.away { row(away) }
            if let home = summary.home { row(home) }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "1 2 3 4" plus "OT", "2OT", … past regulation.
    private var periodLabels: [String] {
        let count = max(summary.away?.linescores.count ?? 0, summary.home?.linescores.count ?? 0)
        return (1...max(count, 1)).map { period in
            period <= 4 ? "\(period)" : (period == 5 ? "OT" : "\(period - 4)OT")
        }
    }

    private func row(_ side: GameSummary.Side) -> GridRow<some View> {
        GridRow {
            // The team column soaks up the card's spare width, so the
            // numeric columns sit as one block against the trailing edge
            // instead of stranding dead space to their right.
            Text(side.team.abbreviation ?? side.team.location)
                .font(side.winner == true ? .teamNameEmphasis : .teamName)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(periodLabels.indices), id: \.self) { index in
                Text(index < side.linescores.count ? side.linescores[index] : "–")
                    .font(.teamName.monospacedDigit())
                    .foregroundStyle(.textPrimary)
            }
            Text(side.score.map(String.init) ?? "–")
                .font(.teamNameEmphasis.monospacedDigit())
                .foregroundStyle(.textPrimary)
        }
    }
}
