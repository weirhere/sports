import SwiftUI

/// The bordered header row the team-page cards share ("Next game",
/// "Schedule", "Standings"): title over a full-bleed hairline, the P1
/// review's table-header treatment.
struct CardHeader: View {
    let title: String
    /// Trailing context in meta type — e.g. Team stats' "UGA · TENN"
    /// column legend.
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.sectionHeader)
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                }
            }
            .padding(Spacing.md)
            Divider().overlay(Color.divider)
        }
    }
}
