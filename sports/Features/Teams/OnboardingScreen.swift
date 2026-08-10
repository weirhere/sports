import SwiftUI

/// The first-launch moment: pick your teams so Saturday starts personal.
/// Entirely skippable — Skip in the toolbar, or just swipe the sheet away;
/// either way it never comes back (the Teams tab does the same job later).
struct OnboardingScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(TeamDirectoryStore.self) private var directory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var searchText = ""

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26

    private var conferences: [ConferenceTeams] { directory.conferences }

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
        .task { await directory.load() }
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

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

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
                // At accessibility sizes the nickname drops under the
                // location; side by side, both collapse to ellipses and the
                // first screen a new user sees is unreadable.
                let location = Text(team.location)
                    .font(isFollowing ? .teamNameEmphasis : .teamName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(isStacked ? 2 : 1)
                let nickname = team.name.map {
                    Text($0)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(isStacked ? 2 : 1)
                }
                if isStacked {
                    VStack(alignment: .leading, spacing: 2) {
                        location
                        nickname
                    }
                } else {
                    location
                    nickname
                }
                Spacer(minLength: Spacing.sm)
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

    // No follow boost here: rows toggle follows, and a followed-first sort
    // would reorder the list under the user's finger.
    private var searchResults: [Team] {
        SearchResults.teams(matching: searchText, in: conferences)
    }
}

#Preview {
    OnboardingScreen()
        .environment(FollowingStore())
        .environment(TeamDirectoryStore())
}
