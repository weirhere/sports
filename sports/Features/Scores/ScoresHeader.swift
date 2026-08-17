import SwiftUI

/// The chrome row above the week strip: StatSide wordmark left; grouping
/// toggle and season picker right, both capsule chips.
struct ScoresHeader: View {
    let seasonYear: Int?
    let seasons: [Int]
    let byDate: Bool
    let onSelectSeason: (Int) -> Void
    let onToggleGrouping: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            wordmark
            Spacer()
            GroupingChip(byDate: byDate, onToggle: onToggleGrouping)
            if let seasonYear {
                SeasonMenuChip(current: seasonYear, seasons: seasons, onSelect: onSelectSeason)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    private var wordmark: some View {
        HStack(spacing: Spacing.xs + 2) {
            Image(systemName: "football.fill")
                .font(.system(size: 15, weight: .semibold))
            Text("StatSide")
                .font(.system(size: 17, weight: .heavy))
        }
        .foregroundStyle(.textPrimary)
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ScoresHeader(seasonYear: 2026, seasons: Array(stride(from: 2026, through: 2014, by: -1)),
                     byDate: false, onSelectSeason: { _ in }, onToggleGrouping: {})
        ScoresHeader(seasonYear: nil, seasons: [],
                     byDate: true, onSelectSeason: { _ in }, onToggleGrouping: {})
    }
    .background(Color.bgPrimary)
}
