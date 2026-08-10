import SwiftUI

/// The tables hub, FotMob-Leagues-shaped: a list of rows — Top 25 first,
/// then every conference, followed ones pinned. The poll lives one tap
/// down so the conferences aren't buried under 25 rank rows.
struct RankingsScreen: View {
    /// The FBS polls we show, in picker order. ESPN's response also carries
    /// FCS and DII/DIII polls — filtered out.
    private static let pollTypes = ["ap", "usa", "cfp"]

    @Environment(FollowingStore.self) private var following

    @State private var polls: [Poll] = []
    @State private var conferences: [ConferenceStandings] = []
    @State private var isLoading = false
    @State private var lastError: String?

    private let client: any ScoresProviding = DataProvider.makeClient()

    var body: some View {
        NavigationStack {
            content
                .background(Color.bgPrimary)
                .navigationTitle("Rankings")
                .navigationBarTitleDisplayMode(.inline)
                // TeamPage is pushed view-based here, but its standing line
                // and a standings row's team both push values — register
                // them so those links work inside this stack too.
                .navigationDestination(for: ConferenceDestination.self) { destination in
                    ConferencePage(destination: destination)
                }
                .navigationDestination(for: Team.self) { team in
                    TeamPage(team: team)
                }
        }
        .task { await load() }
    }

    private var displayedPolls: [Poll] {
        Self.pollTypes.compactMap { type in polls.first { $0.type == type } }
    }

    /// Followed conferences pinned above the mappers' tier-then-name order.
    private var orderedConferences: [ConferenceStandings] {
        ConferenceStandings.pinned(conferences, followedIds: following.conferenceIds)
    }

    @ViewBuilder
    private var content: some View {
        if !displayedPolls.isEmpty || !orderedConferences.isEmpty {
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if !displayedPolls.isEmpty {
                        Top25Row(polls: displayedPolls)
                            .padding(.vertical, Spacing.xs)
                            .cardSurface()
                    }
                    if !orderedConferences.isEmpty {
                        // One card per conference, FotMob-Leagues style —
                        // the header floats on the recessed background
                        // between the Top 25 card and the run of cards.
                        Text("CONFERENCES")
                            .font(.sectionHeader)
                            .foregroundStyle(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.sm)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(orderedConferences) { conference in
                            ConferenceListRow(conference: conference)
                                .padding(.vertical, Spacing.xs)
                                .cardSurface()
                        }
                    }
                }
                .padding(Spacing.sm)
            }
            .background(Color.bgRecessed)
            .refreshable { await load() }
        } else if isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else {
            Spacer()
            Text(lastError ?? "No rankings right now")
                .font(.teamName)
                .foregroundStyle(.textSecondary)
            Button("Retry") {
                Task { await load() }
            }
            .font(.teamNameEmphasis)
            .foregroundStyle(.textPrimary)
            Spacer()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        // The two fetches fail independently: no poll is a screen-level
        // error only when there are no conferences either; a standings miss
        // just hides the CONFERENCES card under a healthy Top 25 row.
        async let pollsFetch = client.rankings()
        async let standingsFetch = client.conferenceStandings()
        do {
            polls = try await pollsFetch
            lastError = nil
        } catch {
            lastError = "Couldn't load rankings."
        }
        conferences = (try? await standingsFetch) ?? []
    }
}
