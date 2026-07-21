import SwiftUI

/// The first-launch moment: pick your teams so Saturday starts personal.
/// Entirely skippable — Skip in the toolbar, or just swipe the sheet away;
/// either way it never comes back (the Teams tab does the same job later).
struct OnboardingScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(\.dismiss) private var dismiss

    @State private var conferences: [ConferenceTeams] = []
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var searchText = ""

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26

    private let client: any ScoresProviding = DataProvider.makeClient()

    var body: some View {
        NavigationStack {
            content
                .background(Color.bgRecessed)
                .navigationTitle("Pick your teams")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(following.followsAnyone ? "Done" : "Skip") { dismiss() }
                            .font(.chip)
                            .foregroundStyle(.textPrimary)
                    }
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
                LazyVStack(spacing: Spacing.sm) {
                    if searchText.isEmpty {
                        subtitle
                        ForEach(conferences) { conference in
                            conferenceSection(conference)
                        }
                    } else if !searchResults.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchResults) { team in
                                teamRow(team)
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                        .cardSurface()
                    }
                }
                .padding(Spacing.sm)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                SearchField(text: $searchText, prompt: "Find a team")
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)
                    .background(Color.bgRecessed)
            }
        }
    }

    private var subtitle: some View {
        Text("Your teams lead the Scores screen every Saturday. You can always change them from the Teams tab.")
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.xs)
    }

    private func conferenceSection(_ conference: ConferenceTeams) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                if let logoURL = Conference.logoURL(for: conference.id) {
                    ConferenceLogo(url: logoURL)
                }
                Text(conference.name)
                    .font(.sectionHeader)
                    .foregroundStyle(.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.bgHeader)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(conference.name)
            .accessibilityAddTraits(.isHeader)

            ForEach(conference.teams) { team in
                teamRow(team)
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    /// The whole row is the follow toggle — a bigger target than the star
    /// alone, which is what a first-launch moment wants.
    private func teamRow(_ team: Team) -> some View {
        let isFollowing = following.isFollowing(team.id)
        return Button {
            following.toggle(team.id)
        } label: {
            HStack(spacing: Spacing.md) {
                LogoImage(url: team.logoURL)
                    .frame(width: logoSize, height: logoSize)
                Text(team.location)
                    .font(isFollowing ? .teamNameEmphasis : .teamName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                if let nickname = team.name {
                    Text(nickname)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isFollowing ? "star.fill" : "star")
                    .font(.system(size: 16))
                    .foregroundStyle(.textPrimary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(team.displayName ?? team.location)
        .accessibilityValue(isFollowing ? "following" : "not following")
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

#Preview {
    OnboardingScreen()
        .environment(FollowingStore())
}
