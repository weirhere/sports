import SwiftUI

/// The Schedule card's contents on a team page: header, game rows, and the
/// loading/error/empty states. The season chip moved to the hero header in
/// the P1 review, so this section is purely the list.
struct TeamScheduleSection: View {
    let teamId: String
    let games: [Game]
    let isLoading: Bool
    let showsError: Bool
    /// The week this team is off, when its league assigns one. Slotted
    /// between the games either side of it rather than left as a silent
    /// jump from Week 7 to Week 9 — an NFL fan plans around the bye.
    var byeWeek: Int? = nil
    let onRetry: () -> Void

    var body: some View {
        CardHeader(title: "Schedule")
        if !games.isEmpty {
            ForEach(games) { game in
                // Rows push game detail (Andy, 2026-08-25); the Teams and
                // Tables stacks both register the Game destination.
                NavigationLink(value: game) {
                    ScheduleRow(game: game, teamId: teamId)
                }
                .buttonStyle(.plain)
                if showsBye(after: game) {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                    byeRow
                }
                if game.id != games.last?.id {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                }
            }
        } else if isLoading {
            ProgressView().padding(.vertical, Spacing.xl)
        } else if showsError {
            StatusMessage(text: "Couldn't load the schedule.", retry: onRetry)
        } else {
            // Reachable when the current-season fallback found both years
            // empty, or when an explicitly picked season is unpublished.
            StatusMessage(text: "Schedule TBA")
        }
    }

    /// The bye sits after the last game before it, so the list stays in
    /// week order without needing a synthetic Game to sort.
    private func showsBye(after game: Game) -> Bool {
        guard let byeWeek, let week = game.weekNumber else { return false }
        guard week < byeWeek else { return false }
        // The next game is on the far side of the bye — or there is none,
        // and the bye closes the list.
        guard let index = games.firstIndex(where: { $0.id == game.id }) else { return false }
        let next = games[(index + 1)...].first { $0.weekNumber != nil }
        return next.map { ($0.weekNumber ?? 0) > byeWeek } ?? true
    }

    private var byeRow: some View {
        HStack {
            Text("Week \(byeWeek ?? 0)")
                .font(.rowMetaMedium)
                .foregroundStyle(.textSecondary)
            Spacer()
            Text("BYE")
                .font(.chipEmphasis)
                .tracking(0.4)
                .foregroundStyle(.textSecondary)
        }
        .padding(Spacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Week \(byeWeek ?? 0), bye week")
    }
}
