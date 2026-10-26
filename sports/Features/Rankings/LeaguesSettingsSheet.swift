import SwiftUI

/// The Leagues page's own settings (Andy, 2026-10-26): how each league's
/// Scores slate is grouped — by league, conference or division. A chip on
/// every league's card from 2026-10-19 until today, when it moved here to
/// clear the cards back to mark, name and Follow. Still one home for the
/// choice — the page about the leagues — just behind one button rather
/// than four.
struct LeaguesSettingsSheet: View {
    @Environment(UIStateStore.self) private var uiState
    @Environment(\.dismiss) private var dismiss

    @ScaledMetric(relativeTo: .subheadline) private var markSize: CGFloat = 22

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(League.displayOrder, id: \.self) { league in
                        Picker(selection: binding(for: league)) {
                            ForEach(SlateGrouping.options(for: league), id: \.self) { grouping in
                                Text(grouping.label).tag(grouping)
                            }
                        } label: {
                            HStack(spacing: Spacing.md) {
                                ConferenceLogo(url: league.logoURL, league: league)
                                    .frame(width: markSize, height: markSize)
                                Text(league.displayName)
                                    .font(.teamName)
                                    .foregroundStyle(.textPrimary)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.textSecondary)
                        .accessibilityLabel("Group \(league.spokenName) games by")
                        .accessibilityIdentifier("leagues.grouping.\(league.rawValue)")
                    }
                } header: {
                    Text("Group games by")
                } footer: {
                    Text("How each league's games are split into sections on the Scores page.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bgRecessed)
            .listRowBackground(Color.bgCard)
            .navigationTitle("Leagues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func binding(for league: League) -> Binding<SlateGrouping> {
        Binding(get: { uiState.grouping(for: league) },
                set: { uiState.setGrouping($0, for: league) })
    }
}
