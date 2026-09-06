import SwiftUI

/// The join-a-team sheet: a search field over the whole directory, with a
/// curated shortlist standing in until the first keystroke, and the list
/// swapping to results the moment there is one (Andy, 2026-09-05).
///
/// Rows toggle follows rather than navigating — the sheet's question is
/// "which teams are mine?", and a page visit isn't part of answering it.
/// The Teams tab behind it is where a followed team's page is one tap away.
struct AddTeamsSheet: View {
    @Environment(FollowingStore.self) private var following
    @Environment(TeamDirectoryStore.self) private var directory
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            content
                .background(Color.bgRecessed)
                .navigationTitle("Add teams")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .font(.chip)
                            .foregroundStyle(.textPrimary)
                    }
                }
        }
        // Full height, not a medium detent that the keyboard would swallow
        // the moment anyone typed: search is the point of the sheet.
        .presentationDetents([.large])
        // Retry lands here if the directory failed before the sheet opened.
        .task { await directory.load() }
    }

    @ViewBuilder
    private var content: some View {
        if directory.conferences.isEmpty {
            TeamDirectoryPlaceholder()
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if searchText.isEmpty {
                        ForEach(popular) { group in
                            ListSectionHeading(title: group.league.displayName)
                            teamCard(group.teams)
                        }
                    } else if !searchResults.isEmpty {
                        let spansLeagues = Set(searchResults.map(\.league)).count > 1
                        teamCard(searchResults, leagueTags: spansLeagues)
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
                SearchField(text: $searchText, prompt: "Find a team",
                            identifier: "search.addTeams")
                    .padding(.horizontal, Spacing.sm)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)
                    .background(Color.bgRecessed)
            }
        }
    }

    /// Keyed on the follow key, never the bare id: UCLA and the Seahawks
    /// are both team 26, and duplicate identities inside one LazyVStack
    /// corrupt its layout into blank card-sized gaps.
    private func teamCard(_ teams: [Team], leagueTags: Bool = false) -> some View {
        VStack(spacing: 0) {
            ForEach(teams, id: \.followKey) { team in
                TeamFollowRow(team: team, leagueTag: leagueTags ? team.league : nil)
            }
        }
        .padding(.vertical, Spacing.xs)
        .cardSurface()
    }

    private var popular: [PopularTeams.Group] {
        PopularTeams.groups(in: directory.conferences)
    }

    /// No follow boost: rows toggle follows here, and a followed-first sort
    /// would reorder the list under the user's finger.
    private var searchResults: [Team] {
        SearchResults.teams(matching: searchText, in: directory.conferences,
                            preferredLeague: following.preferredLeague)
    }
}

#Preview {
    Color.bgPrimary
        .sheet(isPresented: .constant(true)) {
            AddTeamsSheet()
                .environment(FollowingStore())
                .environment(TeamDirectoryStore())
        }
}
