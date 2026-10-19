import SwiftUI

/// How one league's Scores slate is broken down — a menu chip on the
/// league's heading in the Leagues tab (Andy, 2026-10-19: "the group games
/// by league, conference, division should actually go on the leagues
/// page"). It moved here from Settings' "Group games by" section
/// (2026-10-03) rather than being copied: one home for a per-league
/// choice, beside the league it is about, and the section that listed four
/// leagues in a sheet off Scores is gone.
///
/// The season chip's shape, compact: the current rung and the up-down
/// chevron in `chip` type on a quiet capsule. It fills nothing when
/// active — every rung is a view choice, not a narrowing — so the chip
/// reads as a control, not a state.
struct SlateGroupingChip: View {
    let league: League

    @Environment(UIStateStore.self) private var uiState

    var body: some View {
        let current = uiState.grouping(for: league)
        Menu {
            Picker("Group games by", selection: Binding(
                get: { current },
                set: { uiState.setGrouping($0, for: league) }
            )) {
                ForEach(SlateGrouping.options(for: league), id: \.self) { grouping in
                    Text(grouping.label).tag(grouping)
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(current.label)
                    .font(.chip)
                    .lineLimit(1)
                    .fixedSize()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.bgElevated))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Group \(league.spokenName) games by")
        .accessibilityValue(current.label)
        .accessibilityIdentifier("leagues.grouping.\(league.rawValue)")
    }
}
