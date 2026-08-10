import SwiftUI

/// Browse and search the FBS, grouped by conference (from the standings
/// API — the one source that knows membership).
struct TeamsScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState
    @Environment(Router.self) private var router
    @Environment(TeamDirectoryStore.self) private var directory

    @State private var searchText = ""
    @State private var path: [Team] = []
    /// Drives the browse list's scroll — set when a search result lands on
    /// a conference, tracked (harmlessly) as the user scrolls.
    @State private var scrolledSection: String?

    private var conferences: [ConferenceTeams] { directory.conferences }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Color.bgPrimary)
                .navigationTitle("Teams")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Team.self) { team in
                    TeamPage(team: team)
                }
        }
        .task { await directory.load() }
        // Tab content is created lazily (iOS 18 Tab builder), so an intent
        // set before the first visit predates the onChange observers —
        // onAppear catches it.
        .onAppear {
            resolvePendingTeam()
            resolvePendingConference()
        }
        .onChange(of: router.pendingTeamId) { _, _ in resolvePendingTeam() }
        .onChange(of: router.pendingConferenceId) { _, _ in resolvePendingConference() }
        .onChange(of: directory.conferences) { _, _ in
            resolvePendingTeam()
            resolvePendingConference()
        }
    }

    /// Lands a deep-linked team once the browse data is loaded; an unknown
    /// id degrades to landing on the Teams tab.
    private func resolvePendingTeam() {
        guard let pendingId = router.pendingTeamId,
              let team = conferences.flatMap(\.teams).first(where: { $0.id == pendingId }) else { return }
        router.pendingTeamId = nil
        path = [team]
    }

    /// Lands a search result's conference: browse list, section expanded,
    /// scrolled to the top of the card. The seam a dedicated conference
    /// destination would take over — search itself only emits the intent.
    private func resolvePendingConference() {
        guard let pendingId = router.pendingConferenceId,
              let conference = conferences.first(where: { $0.id == pendingId }) else { return }
        router.pendingConferenceId = nil
        searchText = ""
        path = []
        let sectionId = sectionId(for: conference)
        uiState.expandConference(sectionId)
        // The intent arrives while the search cover is still dismissing and
        // the tab switch is in flight; a scroll set before this ScrollView
        // has laid out is silently dropped.
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation { scrolledSection = sectionId }
        }
    }

    @ViewBuilder
    private var content: some View {
        if conferences.isEmpty {
            VStack(spacing: Spacing.md) {
                Spacer()
                if directory.isLoading {
                    ProgressView()
                } else {
                    Text(directory.lastError ?? "No teams")
                        .font(.teamName)
                        .foregroundStyle(.textSecondary)
                    Button("Retry") {
                        Task { await directory.load() }
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
                                .id(Self.followingSectionId)
                        }
                        ForEach(conferences) { conference in
                            teamSection(title: conference.name,
                                        sectionId: sectionId(for: conference),
                                        teams: conference.teams,
                                        logoURL: Conference.logoURL(for: conference.id),
                                        isConference: true)
                                .id(sectionId(for: conference))
                        }
                    } else if !searchResults.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchResults) { team in
                                TeamBrowseRow(team: team)
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                        .cardSurface()
                    } else {
                        Text("No teams match “\(searchText.trimmingCharacters(in: .whitespaces))”")
                            .font(.teamName)
                            .foregroundStyle(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.xl)
                    }
                }
                .padding(Spacing.sm)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrolledSection, anchor: .top)
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
                             logoURL: URL? = nil, isConference: Bool = false) -> some View {
        let isExpanded = !uiState.isConferenceCollapsed(sectionId)
        return VStack(spacing: 0) {
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
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(Color.bgHeader)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(teams.count) \(teams.count == 1 ? "team" : "teams")")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .accessibilityAddTraits(.isHeader)

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
        SearchResults.teams(matching: searchText, in: conferences,
                            followingIds: following.teamIds)
    }
}
