import SwiftUI

/// Team mark, name over the years, and the stint's record.
struct CoachStintRow: View {
    let stint: CoachStint
    let label: CoachClient.TeamLabel
    let league: League
    let isLink: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            LogoImage(url: label.logoURL)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.name)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                Text(stint.span(league: league))
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            if let record = stint.record {
                Text(record.summary)
                    .font(.teamNameEmphasis.monospacedDigit())
                    .foregroundStyle(.textPrimary)
            }
            if isLink {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
