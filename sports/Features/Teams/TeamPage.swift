import SwiftUI

/// One team's home: identity, record, follow, and their season schedule.
struct TeamPage: View {
    let team: Team

    @State private var schedule: TeamSchedule?
    @State private var isLoading = false
    @State private var lastError: String?

    private let client: any ScoresProviding = ESPNClient()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider().overlay(Color.divider)
                scheduleSection
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle(team.location)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            LogoImage(url: team.logoURL)
                .frame(width: 64, height: 64)
            Text(team.displayName ?? team.location)
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            HStack(spacing: Spacing.sm) {
                if let record = schedule?.record {
                    Text(record)
                        .font(.metaEmphasis)
                        .foregroundStyle(.textPrimary)
                }
                if let standing = schedule?.standing {
                    Text(standing)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                }
            }
            followPill
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    private var followPill: some View {
        FollowPill(teamId: team.id)
    }

    @ViewBuilder
    private var scheduleSection: some View {
        if let games = schedule?.games, !games.isEmpty {
            Text("SCHEDULE")
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            ForEach(games) { game in
                ScheduleRow(game: game, teamId: team.id)
                if game.id != games.last?.id {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                }
            }
        } else if isLoading {
            ProgressView().padding(.vertical, Spacing.xl)
        } else if lastError != nil {
            VStack(spacing: Spacing.sm) {
                Text("Couldn't load the schedule.")
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
                Button("Retry") {
                    Task { await load(force: true) }
                }
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            }
            .padding(.vertical, Spacing.xl)
        } else {
            // ESPN publishes next season's schedules late; July can be empty.
            Text("Schedule TBA")
                .font(.teamName)
                .foregroundStyle(.textSecondary)
                .padding(.vertical, Spacing.xl)
        }
    }

    private func load(force: Bool = false) async {
        guard schedule == nil || force else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            schedule = try await client.teamSchedule(teamId: team.id)
            lastError = nil
        } catch {
            lastError = "Couldn't load the schedule."
        }
    }
}
