import SwiftUI

/// Stands in for the Following section on a day when nothing you follow
/// plays (Andy, 2026-09-26). It keeps the boundary the Hide all/Show all
/// control needs — something above it that is yours — so the rest of the
/// slate can still be folded away. Plain centered text on the page
/// background rather than a card: with no rows to open, a card would read
/// as a section that failed to load.
///
/// Under the Live filter the section has been narrowed to games in progress,
/// so "No games today" would be wrong when your team plays tonight — it says
/// "No ongoing games" instead (Andy, 2026-10-03).
struct FollowingEmptyHeader: View {
    var liveOnly = false

    private var message: String { liveOnly ? "No ongoing games" : "No games today" }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text("Following")
                .font(.followingEmptyTitle)
                .foregroundStyle(.textPrimary)
            Text(message)
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.md)
        // Triples the gap to the Hide all capsule: the stack's own 8pt plus
        // the capsule's 4pt top padding is 12, and this makes it 36.
        .padding(.bottom, Spacing.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Following, \(message.lowercased())")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("scores-following-empty")
    }
}

#Preview {
    VStack(spacing: Spacing.sm) {
        FollowingEmptyHeader()
        HideAllControl(others: [], isHidden: false, onToggle: {})
    }
    .padding()
    .background(Color.bgRecessed)
}
