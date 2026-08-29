import SwiftUI

/// The season picker: a capsule chip opening a menu of years, newest
/// first. Shared by the Scores header and TeamPage so the two read as one
/// control.
struct SeasonMenuChip: View {
    let current: Int
    let seasons: [Int]
    let onSelect: (Int) -> Void
    /// Team-color hero styling: white text on a translucent scrim instead
    /// of the elevated capsule.
    var onDark = false

    var body: some View {
        Menu {
            Picker("Season", selection: Binding(get: { current }, set: onSelect)) {
                ForEach(seasons, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
        } label: {
            // Same capsule as the Scores header chips so the chrome chips
            // read as one family.
            HStack(spacing: Spacing.xs) {
                Text(String(current))
                    .font(.chip)
                    .lineLimit(1)
                    .fixedSize()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(onDark ? .white : Color.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
            // A dark tint on hero color keeps the white label legible —
            // untinted glass washed out against the team paint.
            .glassCapsuleInteractive(tint: onDark ? Color.black.opacity(0.35) : nil,
                                     fallback: onDark ? Color.black.opacity(0.3) : Color.bgElevated)
            // Compact capsule, 44 pt tap target.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(seasons.isEmpty)
        .accessibilityLabel("Season, \(String(current))")
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
