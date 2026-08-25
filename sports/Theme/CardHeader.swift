import SwiftUI

/// The bordered header row the team-page cards share ("Next game",
/// "Schedule", "Standings"): title over a full-bleed hairline, the P1
/// review's table-header treatment.
struct CardHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .accessibilityAddTraits(.isHeader)
            Divider().overlay(Color.divider)
        }
    }
}
