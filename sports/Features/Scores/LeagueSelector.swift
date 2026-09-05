import SwiftUI

/// Which league the Scores screen is scoped to.
///
/// The league has to be a scope rather than a filter because the week strip
/// underneath it is league-shaped: college football's "Bowls" is one slot
/// running mid-December to late January, with four NFL playoff rounds
/// sitting inside it. There is no shared week to put both on.
///
/// Styled as the leading segment of the header's grouped control, the same
/// language as the Live pill and the funnel (Andy, 2026-08-29): the
/// enclosing capsule belongs to `ScoresHeader`, so each segment paints only
/// its own active fill. Monochrome — the league marks are the color, under
/// the budget's logo exception.
struct LeagueSelector: View {
    let selected: League
    let onSelect: (League) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(League.allCases) { league in
                segment(league)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("League")
    }

    private func segment(_ league: League) -> some View {
        let isSelected = league == selected
        return Button {
            onSelect(league)
        } label: {
            Text(league.shortName)
                .font(.chipEmphasis)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? Color.bgPrimary : Color.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(isSelected ? Color.textPrimary : Color.clear)
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(league.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        LeagueSelector(selected: .collegeFootball, onSelect: { _ in })
        LeagueSelector(selected: .nfl, onSelect: { _ in })
    }
    .padding(4)
    .background(Capsule().fill(Color.bgElevated))
    .padding()
    .background(Color.bgPrimary)
}
