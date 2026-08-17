import SwiftUI

/// The SCHEDULE block on a team page: season chip, game rows, and the
/// loading/error/empty states. The chip stays mounted through all of
/// them so an empty or failed season never strands the user there.
struct TeamScheduleSection: View {
    let teamId: String
    let games: [Game]
    let selectedYear: Int?
    let seasons: [Int]
    let isLoading: Bool
    let showsError: Bool
    let onSelectYear: (Int) -> Void
    let onRetry: () -> Void

    var body: some View {
        // The header waits for the first load — the chip needs a year to
        // show, and a header over the initial spinner would be noise.
        if selectedYear != nil {
            header
        }
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

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Text("SCHEDULE")
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
            Spacer()
            if let selectedYear {
                SeasonMenuChip(current: selectedYear, seasons: seasons, onSelect: onSelectYear)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
    }
}
