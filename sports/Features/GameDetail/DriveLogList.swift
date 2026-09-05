import SwiftUI

/// Every possession, chronological with quarter markers: who had the ball
/// and what came of it. Scoring drives get weight; the rest stay quiet.
struct DriveLogList: View {
    let summary: GameSummary

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 16

    var body: some View {
        // The card's CardHeader names the section now; this view is just
        // the rows.
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(summary.drives.enumerated()), id: \.element.id) { index, drive in
                if periodMarker(at: index) {
                    Text(PeriodLabel.text(drive.period))
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, index == 0 ? Spacing.sm : Spacing.lg)
                        .padding(.bottom, Spacing.xs)
                }
                driveRow(drive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.sm)
    }

    private func periodMarker(at index: Int) -> Bool {
        index == 0 || summary.drives[index].period != summary.drives[index - 1].period
    }

    private func driveRow(_ drive: Drive) -> some View {
        HStack(spacing: Spacing.md) {
            LogoImage(url: summary.team(withId: drive.teamId)?.logoURL)
                .frame(width: logoSize, height: logoSize)
            Text(drive.result ?? "—")
                .font(drive.isScore ? .metaEmphasis : .meta)
                .foregroundStyle(.textPrimary)
            Spacer(minLength: Spacing.sm)
            if let summary = drive.summary {
                Text(summary)
                    .font(.meta.monospacedDigit())
                    .foregroundStyle(.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(for: drive))
    }

    /// One spoken sentence: "Miami, punt, 5 plays, 20 yards, 2:39".
    /// Internal, not private, so the label shape is unit-testable.
    func accessibilitySummary(for drive: Drive) -> String {
        var parts: [String] = []
        if let location = summary.team(withId: drive.teamId)?.location { parts.append(location) }
        if let result = drive.result { parts.append(result.lowercased()) }
        if let summary = drive.summary { parts.append(summary) }
        return parts.joined(separator: ", ")
    }
}
