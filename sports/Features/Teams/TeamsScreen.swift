import SwiftUI

/// Browse and search the FBS, grouped by conference (from the standings
/// API — the one source that knows membership).
struct TeamsScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState
    @Environment(Router.self) private var router

    @State private var conferences: [ConferenceTeams] = []
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var searchText = ""
    // Heterogeneous: browse rows push Team, group headers push
    // ConferenceDestination.
    @State private var path = NavigationPath()

    private let client: any ScoresProviding = DataProvider.makeClient()

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Color.bgPrimary)
                .navigationTitle("Teams")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Team.self) { team in
                    TeamPage(team: team)
                }
                .navigationDestination(for: ConferenceDestination.self) { destination in
                    ConferencePage(destination: destination)
                }
        }
        .task { await load() }
        .onChange(of: router.pendingTeamId) { _, _ in resolvePendingTeam() }
        .onChange(of: conferences) { _, _ in resolvePendingTeam() }
    }

    /// Lands a deep-linked team once the browse data is loaded; an unknown
    /// id degrades to landing on the Teams tab.
    private func resolvePendingTeam() {
        guard let pendingId = router.pendingTeamId,
              let team = conferences.flatMap(\.teams).first(where: { $0.id == pendingId }) else { return }
        router.pendingTeamId = nil
        path = NavigationPath([team])
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
                LazyVStack(spacing: Spacing.sm) {
                    if searchText.isEmpty {
                        if !followedTeams.isEmpty {
                            teamSection(title: "Following",
                                        sectionId: Self.followingSectionId,
                                        teams: followedTeams)
                        }
                        ForEach(conferences) { conference in
                            teamSection(title: conference.name,
                                        sectionId: sectionId(for: conference),
                                        teams: conference.teams,
                                        logoURL: Conference.logoURL(for: conference.id),
                                        isConference: true,
                                        conferenceId: conference.id)
                        }
                    } else if !searchResults.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchResults) { team in
                                TeamBrowseRow(team: team)
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                        .cardSurface()
                    }
                }
                .padding(Spacing.sm)
            }
            .background(Color.bgRecessed)
            .safeAreaInset(edge: .top, spacing: 0) {
                SearchField(text: $searchText, prompt: "Find a team")
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)
                    .background(Color.bgRecessed)
            }
        }
    }

    private func teamSection(title: String, sectionId: String, teams: [Team],
                             logoURL: URL? = nil, isConference: Bool = false,
                             conferenceId: Int? = nil) -> some View {
        let isExpanded = !uiState.isConferenceCollapsed(sectionId)
        // Same two-button header shape as the Scores accordions: the toggle
        // owns the width, the standings link is its own trailing target.
        let openStandings: (() -> Void)? = conferenceId.map { id in
            { path.append(ConferenceDestination(conferenceId: id, name: title)) }
        }
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    withAnimation { uiState.toggleConference(sectionId) }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if isConference {
                            ConferenceLogo(url: logoURL)
                        }
                        Text(title)
                            .font(.sectionHeader)
                            .foregroundStyle(.textPrimary)
                        Text("\(teams.count)")
                            .font(.meta)
                            .foregroundStyle(.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .padding(.leading, Spacing.lg)
                    .padding(.trailing, openStandings == nil ? Spacing.lg : Spacing.sm)
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title), \(teams.count) \(teams.count == 1 ? "team" : "teams")")
                .accessibilityValue(isExpanded ? "expanded" : "collapsed")
                .accessibilityAddTraits(.isHeader)
                .contextMenu {
                    if let openStandings {
                        Button {
                            openStandings()
                        } label: {
                            Label("View \(title) standings", systemImage: "list.number")
                        }
                    }
                }
                .accessibilityActions {
                    if let openStandings {
                        Button("View \(title) standings", action: openStandings)
                    }
                }

                if let openStandings {
                    ConferenceStandingsLink(conferenceName: title, onOpen: openStandings)
                        .padding(.trailing, Spacing.xs)
                }
            }
            .background(Color.bgHeader)

            if isExpanded {
                ForEach(teams) { team in
                    TeamBrowseRow(team: team)
                }
            }
        }
        .padding(.bottom, isExpanded ? Spacing.xs : 0)
        .cardSurface()
    }

    private static let followingSectionId = "teams.following"

    private func sectionId(for conference: ConferenceTeams) -> String {
        "teams.conf.\(conference.id.map(String.init) ?? "other")"
    }

    private var followedTeams: [Team] {
        conferences.flatMap(\.teams)
            .filter { following.isFollowing($0.id) }
            .sorted { $0.location.localizedCaseInsensitiveCompare($1.location) == .orderedAscending }
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
