import SwiftUI

/// The poll. AP by default; Coaches and CFP as chips (CFP only appears
/// when ESPN returns it, i.e. from late October).
struct RankingsScreen: View {
    /// The FBS polls we show, in picker order. ESPN's response also carries
    /// FCS and DII/DIII polls — filtered out.
    private static let pollTypes = ["ap", "usa", "cfp"]

    @Environment(UIStateStore.self) private var uiState

    @State private var polls: [Poll] = []
    @State private var isLoading = false
    @State private var lastError: String?

    private let client: any ScoresProviding = ESPNClient()

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

    @ViewBuilder
    private var content: some View {
        if let poll = selectedPoll {
            ScrollView {
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
                        RankRow(ranked: ranked)
                        if ranked.id != poll.ranks.last?.id {
                            Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                        }
                    }
                }
            }
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
        do {
            polls = try await client.rankings()
            lastError = nil
        } catch {
            lastError = "Couldn't load rankings."
        }
    }
}
