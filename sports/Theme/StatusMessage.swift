import SwiftUI

/// The quiet load-status block a tab pane shows instead of content — a
/// secondary-ink message, with a Retry button when the load failed. One
/// voice for every "Standings TBA" / "Couldn't load…" across the entity
/// pages and the schedule card; the caller adds `.cardSurface()` where the
/// message stands alone (never around a bare spinner, which hugs into a
/// floating pill).
struct StatusMessage: View {
    let text: String
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(text)
                .font(.teamName)
                .foregroundStyle(.textSecondary)
            if let retry {
                Button("Retry", action: retry)
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}
