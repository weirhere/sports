import SwiftUI

/// The Schedule card's contents on a team page: header, game rows, and the
/// loading/error/empty states. The season chip moved to the hero header in
/// the P1 review, so this section is purely the list.
struct TeamScheduleSection: View {
    let teamId: String
    let games: [Game]
    let isLoading: Bool
    let showsError: Bool
    let onRetry: () -> Void

    var body: some View {
        CardHeader(title: "Schedule")
        if !games.isEmpty {
            ForEach(games) { game in
                ScheduleRow(game: game, teamId: teamId)
                if game.id != games.last?.id {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                }
            }
        } else if isLoading {
            ProgressView().padding(.vertical, Spacing.xl)
        } else if showsError {
            VStack(spacing: Spacing.sm) {
                Text("Couldn't load the schedule.")
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
                Button("Retry", action: onRetry)
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
            }
            .padding(.vertical, Spacing.xl)
        } else {
            // Reachable when the current-season fallback found both years
            // empty, or when an explicitly picked season is unpublished.
            Text("Schedule TBA")
                .font(.teamName)
                .foregroundStyle(.textSecondary)
                .padding(.vertical, Spacing.xl)
        }
    }
}
