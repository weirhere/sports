import SwiftUI

/// Browse and search the FBS, grouped by conference (from the standings
/// API — the one source that knows membership).
struct TeamsScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState
    @Environment(Router.self) private var router
    @Environment(TeamDirectoryStore.self) private var directory

    @State private var searchText = ""
    // Heterogeneous: browse rows push Team, group headers push
    // ConferenceDestination — a typed path can't hold both.
    @State private var path = NavigationPath()

    /// Browse order per the P1 review: tier → name (the Rankings mapper's
    /// order), under one "All conferences" heading. The directory keeps its
    /// alphabetical contract for search and onboarding; the reorder is
    /// browse-local. ACC still sorts first — the UI tests lean on that.
    private var conferences: [ConferenceTeams] {
        directory.conferences.sorted {
            let lhs = Conference.tier(for: $0.id), rhs = Conference.tier(for: $1.id)
            if lhs != rhs { return lhs < rhs }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

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
                // TeamPage's Next game card pushes game detail.
                .navigationDestination(for: Game.self) { game in
                    GameDetailScreen(game: game)
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
        path = NavigationPath([team])
    }

    /// Lands a search result's conference on its standings page — the
    /// dedicated destination the search seam was left open for. No data
    /// dependency: the page fetches its own standings, so an intent
    /// resolves immediately even before the browse list has loaded.
    private func resolvePendingConference() {
        guard let pendingId = router.pendingConferenceId else { return }
        router.pendingConferenceId = nil
        searchText = ""
        path = NavigationPath([ConferenceDestination(conferenceId: pendingId,
                                                     name: Conference.name(for: pendingId))])
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
                        ListSectionHeading(title: "All conferences")
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
                    } else {
                        Text("No teams match “\(searchText.trimmingCharacters(in: .whitespaces))”")
                            .font(.teamName)
                            .foregroundStyle(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.xl)
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
        // The header surface is the whole-width toggle; standings live in
        // its context menu + VoiceOver action (the trailing icon came off
        // in the P1 review — Scores headers keep theirs).
        let openStandings: (() -> Void)? = conferenceId.map { id in
            { path.append(ConferenceDestination(conferenceId: id, name: title)) }
        }
        // A conference header splits into two surfaces (Andy's call,
        // 2026-08-25): mark + name push the conference page, the rest
        // toggles. The Following group keeps the whole row as its toggle.
        let identity = HStack(spacing: Spacing.sm) {
            if isConference {
                ConferenceLogo(url: logoURL)
            }
            Text(title)
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
        }
        let toggle = { (content: AnyView) in
            Button {
                withAnimation { uiState.toggleConference(sectionId) }
            } label: {
                content
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
        }
        let countAndChevron = HStack(spacing: Spacing.sm) {
            Text("\(teams.count)")
                .font(.meta)
                .foregroundStyle(.textSecondary)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                if let openStandings {
                    Button(action: openStandings) {
                        identity
                            .padding(.leading, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) standings")
                    toggle(AnyView(
                        countAndChevron
                            .padding(.leading, Spacing.sm)
                            .padding(.trailing, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .contentShape(Rectangle())
                    ))
                } else {
                    toggle(AnyView(
                        HStack(spacing: Spacing.sm) {
                            identity
                            countAndChevron
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .contentShape(Rectangle())
                    ))
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
        SearchResults.teams(matching: searchText, in: conferences,
                            followingIds: following.teamIds)
    }
}
