import SwiftUI

/// The view-options entry point: the trailing segment of the header's
/// grouped control (FotMob's calendar slot), opening `ScoreFilterSheet`.
/// With any non-default state active — a slate filter, a past season, or
/// both — the segment fills and names it ("SEC", "2019", "SEC · 2019"),
/// so a narrowed slate is never a mystery state. Grouping stays out of
/// the label: the section headers on screen already say which view is
/// active. The enclosing capsule belongs to `ScoresHeader`.
struct ScoreFilterChip: View {
    let filter: ScoreFilter?
    /// The selected season when it isn't the current one, nil otherwise.
    let pastSeasonYear: Int?
    let onTap: () -> Void

    private var label: String? {
        let parts = [filter?.chipLabel, pastSeasonYear.map(String.init)].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // The hidden chip-font text gives the icon-only segment the
                // exact height of its text-bearing neighbor — a bare glyph
                // would render a visibly shorter pill.
                ZStack {
                    Text("A").font(.chipEmphasis).hidden()
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 14, weight: .semibold))
                }
                if let label {
                    Text(label)
                        .font(.chipEmphasis)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(label != nil ? Color.bgPrimary : Color.textPrimary)
            .padding(.horizontal, Spacing.md + 2)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(label != nil ? Color.textPrimary : Color.clear)
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.map { "Filtered to \($0)" } ?? "Filter games")
        .accessibilityHint("Shows view options and the conference filter")
        .accessibilityIdentifier("scores-filter-chip")
        .accessibilityAddTraits(label != nil ? .isSelected : [])
    }
}

#Preview {
    HStack {
        ScoreFilterChip(filter: nil, pastSeasonYear: nil, onTap: {})
        ScoreFilterChip(filter: .top25, pastSeasonYear: nil, onTap: {})
        ScoreFilterChip(filter: .conference(8), pastSeasonYear: 2019, onTap: {})
    }
    .padding(4)
    .background(Capsule().fill(Color.bgElevated))
    .padding()
    .background(Color.bgPrimary)
}
