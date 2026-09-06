import SwiftUI

/// The Standings tab's scope control: whole league, conference, or
/// division (Andy, 2026-09-06). A menu capsule, the team filter's twin —
/// the two sit in the same control strip one tab apart and shape their
/// pane the same way.
///
/// It always names its own value, because every scope is a real answer and
/// none of them is the absence of one. The fill is the narrowing signal,
/// `ScoreFilterChip`'s rule: at the page's own widest view the chip sits
/// quiet, and any narrower view wears the ink so a table of 16 is never
/// mistaken for a table of 32.
struct StandingsScopeChip: View {
    let scopes: [StandingsScope]
    let selection: StandingsScope
    /// Whether the selection is narrower than the page's own default.
    let isNarrowed: Bool
    let onSelect: (StandingsScope) -> Void

    var body: some View {
        Menu {
            Picker("Standings", selection: Binding(get: { selection }, set: onSelect)) {
                ForEach(scopes) { scope in
                    Text(scope.title).tag(scope)
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(selection.title)
                    .font(.chip)
                    .lineLimit(1)
                    .fixedSize()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .fixedSize()
            }
            .foregroundStyle(isNarrowed ? Color.bgPrimary : Color.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 8)
            .modifier(SlateChipBackground(isActive: isNarrowed))
            // Compact capsule, 44 pt tap target.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Standings, \(selection.title)")
        .accessibilityHint("Tables the standings by league, conference or division")
        .accessibilityIdentifier("standings-scope-chip")
        .accessibilityAddTraits(isNarrowed ? .isSelected : [])
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        StandingsScopeChip(scopes: StandingsScope.allCases, selection: .league,
                           isNarrowed: false, onSelect: { _ in })
        StandingsScopeChip(scopes: StandingsScope.allCases, selection: .division,
                           isNarrowed: true, onSelect: { _ in })
    }
    .padding()
    .background(Color.bgRecessed)
}
