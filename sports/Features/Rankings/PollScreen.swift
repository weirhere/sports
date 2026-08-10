import SwiftUI

/// The poll itself, one level under the Rankings list: AP by default,
/// Coaches and CFP as chips (CFP only appears when ESPN returns it, i.e.
/// from late October). Rows push team pages.
struct PollScreen: View {
    /// The FBS polls to offer, already filtered and in picker order.
    let polls: [Poll]

    @Environment(UIStateStore.self) private var uiState

    var body: some View {
        VStack(spacing: 0) {
            if polls.count > 1 {
                pollPicker
                Divider().overlay(Color.divider)
            }
            if let poll = selectedPoll {
                ScrollView {
                    pollCard(poll)
                        .padding(Spacing.sm)
                }
                .background(Color.bgRecessed)
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("Top 25")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selectedPoll: Poll? {
        polls.first { $0.type == uiState.pollChoice } ?? polls.first
    }

    private var pollPicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(polls, id: \.id) { poll in
                let isSelected = poll.id == selectedPoll?.id
                Button {
                    uiState.pollChoice = poll.type
                } label: {
                    Text(Self.label(for: poll))
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

    static func label(for poll: Poll) -> String {
        switch poll.type {
        case "ap": "AP"
        case "usa": "Coaches"
        case "cfp": "CFP"
        default: poll.shortName ?? poll.name
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
}
