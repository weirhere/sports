import SwiftUI

/// The Following slot's empty state on Scores: when the user follows
/// nobody, this card does the teaching the census says belongs here —
/// payoff first, one CTA into Teams, and a quiet way out. Monochrome.
struct FollowPromptCard: View {
    @Environment(UIStateStore.self) private var uiState
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "star")
                .font(.system(size: 24))
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
            Text("Follow your teams")
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            Text("They'll lead this screen every Saturday.")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                router.pendingTeamsBrowse = true
            } label: {
                Text("Pick your teams")
                    .font(.chip)
                    .foregroundStyle(Color.bgPrimary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.textPrimary))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xs)
            Button {
                withAnimation { uiState.followPromptDismissed = true }
            } label: {
                Text("Don't show again")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    // The escape hatch stays quiet but keeps a real target.
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.sm)
    }
}
