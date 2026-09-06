import SwiftUI

/// What every directory-backed surface shows before its teams land: a
/// spinner while the standings call is out, the error with a retry once it
/// isn't. Three screens had their own copy of this (Teams, onboarding, and
/// now the Add teams sheet), which is two too many.
struct TeamDirectoryPlaceholder: View {
    @Environment(TeamDirectoryStore.self) private var directory

    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            if directory.isLoading {
                ProgressView()
            } else {
                Text(directory.lastError ?? "No teams")
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
                Button("Retry") {
                    Task { await directory.load() }
                }
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
