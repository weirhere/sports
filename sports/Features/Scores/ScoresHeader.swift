import SwiftUI

/// The chrome row above the week strip: app wordmark left; grouping toggle
/// and season picker right, both capsule chips. The wordmark is a
/// placeholder until the name is settled (BACKLOG open question #1).
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
                seasonMenu(current: seasonYear)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    private var wordmark: some View {
        HStack(spacing: Spacing.xs + 2) {
            Image(systemName: "football.fill")
                .font(.system(size: 15, weight: .semibold))
            Text("CFB")
                .font(.system(size: 17, weight: .heavy))
        }
        .foregroundStyle(.textPrimary)
    }

    private func seasonMenu(current: Int) -> some View {
        Menu {
            Picker("Season", selection: Binding(get: { current }, set: onSelectSeason)) {
                ForEach(seasons, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
        } label: {
            // Same capsule as GroupingChip so the header controls read as
            // one family.
            HStack(spacing: Spacing.xs) {
                Text(String(current))
                    .font(.chip)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.bgElevated))
        }
        .disabled(seasons.isEmpty)
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
