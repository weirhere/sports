import SwiftUI

/// The tables hub: the poll first (AP by default; Coaches and CFP as
/// chips — CFP only appears when ESPN returns it, i.e. from late October),
/// then every conference's standings one tap below, followed ones pinned.
struct RankingsScreen: View {
    /// The FBS polls we show, in picker order. ESPN's response also carries
    /// FCS and DII/DIII polls — filtered out.
    private static let pollTypes = ["ap", "usa", "cfp"]

    @Environment(UIStateStore.self) private var uiState
    @Environment(FollowingStore.self) private var following

    @State private var polls: [Poll] = []
    @State private var conferences: [ConferenceStandings] = []
    @State private var isLoading = false
    @State private var lastError: String?

    private let client: any ScoresProviding = DataProvider.makeClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if displayedPolls.count > 1 {
                    pollPicker
                    Divider().overlay(Color.divider)
                }
                content
            }
            .background(Color.bgPrimary)
            .navigationTitle("Rankings")
            .navigationBarTitleDisplayMode(.inline)
            // TeamPage is pushed view-based here, but its standing line and
            // a standings row's team both push values — register them so
            // those links work inside this stack too.
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

    private var selectedPoll: Poll? {
        displayedPolls.first { $0.type == uiState.pollChoice } ?? displayedPolls.first
    }

    private var pollPicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(displayedPolls, id: \.id) { poll in
                let isSelected = poll.id == selectedPoll?.id
                Button {
                    uiState.pollChoice = poll.type
                } label: {
                    Text(pollLabel(poll))
                        .font(.chip)
                        .foregroundStyle(isSelected ? Color.bgPrimary : Color.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isSelected ? Color.textPrimary : Color.clear))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private func pollLabel(_ poll: Poll) -> String {
        switch poll.type {
        case "ap": "AP"
        case "usa": "Coaches"
        case "cfp": "CFP"
        default: poll.shortName ?? poll.name
        }
    }

    /// Followed conferences pinned above the mappers' tier-then-name order.
    private var orderedConferences: [ConferenceStandings] {
        ConferenceStandings.pinned(conferences, followedIds: following.conferenceIds)
    }

    @ViewBuilder
    private var content: some View {
        if selectedPoll != nil || !orderedConferences.isEmpty {
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if let poll = selectedPoll {
                        pollCard(poll)
                    }
                    if !orderedConferences.isEmpty {
                        conferencesCard
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

    private func pollCard(_ poll: Poll) -> some View {
        LazyVStack(spacing: 0) {
            if let headline = poll.headline {
                Text(headline)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
            }
            ForEach(poll.ranks) { ranked in
                NavigationLink {
                    TeamPage(team: ranked.team)
                } label: {
                    RankRow(ranked: ranked)
                }
                .buttonStyle(.plain)
                if ranked.id != poll.ranks.last?.id {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .cardSurface()
    }

    private var conferencesCard: some View {
        LazyVStack(spacing: 0) {
            Text("CONFERENCES")
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .accessibilityAddTraits(.isHeader)
            ForEach(orderedConferences) { conference in
                ConferenceListRow(conference: conference)
                if conference.id != orderedConferences.last?.id {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .cardSurface()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        // The two fetches fail independently: no poll is a screen-level
        // error only when there are no conferences either; a standings miss
        // just hides the CONFERENCES card under a healthy poll.
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
