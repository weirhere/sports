import SwiftUI

/// The season picker: a capsule chip opening a menu of years, newest
/// first. Shared by the Scores header, TeamPage and ConferencePage so the
/// three read as one control.
struct SeasonMenuChip: View {
    /// Which surface the chip is riding.
    enum Style {
        /// The floating control layer — glass where the OS offers it.
        /// Every chip that sits over content.
        case chrome
        /// The navigation bar, whose background is a solid `bgCard`:
        /// glass over an opaque bar reads as a smudge, and the bar's other
        /// control is the outlined follow pill. So the chip borrows the
        /// pill's shape instead, and the pair reads as one row of controls
        /// (PollScreen, Andy 2026-09-05).
        case bar
    }

    let current: Int
    let seasons: [Int]
    var style: Style = .chrome
    let onSelect: (Int) -> Void

    var body: some View {
        Menu {
            Picker("Season", selection: Binding(get: { current }, set: onSelect)) {
                ForEach(seasons, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
        } label: {
            label
        }
        .disabled(seasons.isEmpty)
        .accessibilityLabel("Season, \(String(current))")
        // A stable handle for the screenshot flow, which has to reach the
        // chip wherever it rides — the Scores strip, a hero toolbar, or a
        // tab pane. Matching the spoken label instead would break every
        // time the wording moves.
        .accessibilityIdentifier("season-chip")
        .accessibilityValue(String(current))
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .chrome:
            // Same capsule as the Scores header chips so the chrome chips
            // read as one family.
            content
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 8)
                .glassCapsuleInteractive(fallback: Color.bgElevated)
                // Compact capsule, 44 pt tap target.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        case .bar:
            content
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 7)
                .overlay(Capsule().strokeBorder(Color.textPrimary, lineWidth: 1))
                .contentShape(Capsule())
        }
    }

    private var content: some View {
        HStack(spacing: Spacing.xs) {
            Text(String(current))
                .font(.chip)
                .lineLimit(1)
                .fixedSize()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color.textPrimary)
    }
}

#Preview {
    SeasonMenuChip(
        current: 2026,
        seasons: Array(stride(from: 2026, through: 2014, by: -1)),
        onSelect: { _ in }
    )
    .padding()
    .background(Color.bgPrimary)
}
