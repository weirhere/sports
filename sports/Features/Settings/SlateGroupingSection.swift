import SwiftUI

/// How each league's Scores slate is broken down — one picker per league
/// (Andy, 2026-10-03). A league listed at every rung at once, its whole
/// slate and then each conference, repeated an NFL game up to three times;
/// one rung per league, chosen here, is the fix. College football defaults
/// to its conferences, the pros to one section each.
struct SlateGroupingSection: View {
    @Environment(UIStateStore.self) private var uiState
    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 24

    var body: some View {
        Section {
            ForEach(League.displayOrder, id: \.self) { league in
                Picker(selection: binding(for: league)) {
                    ForEach(SlateGrouping.options(for: league), id: \.self) { grouping in
                        Text(grouping.label)
                    }
                } label: {
                    // The league's mark beside its name (Andy, 2026-10-03),
                    // as on its Scores sections.
                    HStack(spacing: Spacing.sm) {
                        LogoImage(url: league.logoURL)
                            .frame(width: logoSize, height: logoSize)
                            .accessibilityHidden(true)
                        Text(league.shortName)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.grouping.\(league.rawValue)")
            }
        } header: {
            Text("Group games by")
        } footer: {
            Text("How each league's games are split into sections on the Scores page. A game between two groups appears in both.")
        }
    }

    private func binding(for league: League) -> Binding<SlateGrouping> {
        Binding {
            uiState.grouping(for: league)
        } set: { grouping in
            uiState.setGrouping(grouping, for: league)
        }
    }
}
