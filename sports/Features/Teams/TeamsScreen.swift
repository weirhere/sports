import SwiftUI

/// Browse and search the FBS, grouped by conference (from the standings
/// API — the one source that knows membership).
struct TeamsScreen: View {
    @State private var conferences: [ConferenceTeams] = []
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var searchText = ""

    private let client: any ScoresProviding = ESPNClient()

    var body: some View {
        NavigationStack {
            content
                .background(Color.bgPrimary)
                .navigationTitle("Teams")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Find a team")
                .navigationDestination(for: Team.self) { team in
                    TeamPage(team: team)
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if conferences.isEmpty {
            VStack(spacing: Spacing.md) {
                Spacer()
                if isLoading {
                    ProgressView()
                } else {
                    Text(lastError ?? "No teams")
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    Button("Retry") {
                        Task { await load() }
                    }
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
                }
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if searchText.isEmpty {
                        ForEach(conferences) { conference in
                            Text(conference.name.uppercased())
                                .font(.sectionHeader)
                                .foregroundStyle(.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.md)
                            ForEach(conference.teams) { team in
                                TeamBrowseRow(team: team)
                            }
                            Divider().overlay(Color.divider)
                        }
                    } else {
                        ForEach(searchResults) { team in
                            TeamBrowseRow(team: team)
                        }
                    }
                }
            }
        }
    }

    private var searchResults: [Team] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return conferences.flatMap(\.teams).filter { team in
            [team.location, team.name, team.abbreviation, team.displayName]
                .compactMap(\.self)
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private func load() async {
        guard conferences.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            conferences = try await client.fbsConferences()
            lastError = nil
        } catch {
            lastError = "Couldn't load teams."
        }
    }
}
