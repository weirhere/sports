import SwiftUI

/// The first-launch moment: pick your teams so Saturday starts personal.
/// Entirely skippable — Skip in the toolbar, or just swipe the sheet away;
/// either way it never comes back (the Teams tab does the same job later).
struct OnboardingScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(TeamDirectoryStore.self) private var directory
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var conferences: [ConferenceTeams] { directory.conferences }

    /// Grouped by league, with every pro league above the FCS tail. FCS is
    /// the opt-in long tail (E8 scope (b)); the pro leagues are
    /// first-class, and burying them under fourteen FCS conferences on the
    /// pick-your-teams screen is how nobody would ever find them.
    private var groups: [(title: String, conferences: [ConferenceTeams])] {
        let cfb = conferences.filter { $0.league == .collegeFootball }
        let fbs = cfb.filter { Conference.division(for: $0.id, in: $0.league) != .fcs }
        let fcs = cfb.filter { Conference.division(for: $0.id, in: $0.league) == .fcs }
        let pro = League.allCases
            .filter { $0 != .collegeFootball }
            .map { league in
                (league.displayName, Conference.topLevelIds(in: league).compactMap { id in
                    conferences.first { $0.league == league && $0.id == id }
                })
            }
        return ([("FBS conferences", fbs)] + pro + [("FCS conferences", fcs)])
            .filter { !$0.1.isEmpty }
    }

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
            TeamDirectoryPlaceholder()
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if searchText.isEmpty {
                        subtitle
                        ForEach(groups, id: \.title) { group in
                            ListSectionHeading(title: group.title)
                            ForEach(group.conferences, id: \.rowId) { conference in
                                conferenceSection(conference)
                            }
                        }
                    } else if !searchResults.isEmpty {
                        let spansLeagues = Set(searchResults.map(\.league)).count > 1
                        VStack(spacing: 0) {
                            // Keyed on the follow key, never the bare id:
                            // UCLA and the Seahawks are both team 26.
                            ForEach(searchResults, id: \.followKey) { team in
                                TeamFollowRow(team: team,
                                              leagueTag: spansLeagues ? team.league : nil)
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
        // Was "every Saturday" — true of college football, wrong for a
        // Sunday NFL follow now that both leagues are pickable here.
        Text("Your teams lead the Scores screen every week. You can always change them from the Teams tab.")
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.xs)
    }

    private func conferenceSection(_ conference: ConferenceTeams) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                if let logoURL = Conference.logoURL(for: conference.conference) {
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

            ForEach(conference.teams, id: \.followKey) { team in
                TeamFollowRow(team: team)
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
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
