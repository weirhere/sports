import SwiftUI

/// Every possession, chronological with quarter markers: who had the ball
/// and what came of it. Scoring drives get weight; the rest stay quiet.
struct DriveLogList: View {
    let summary: GameSummary

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DRIVES")
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            ForEach(Array(summary.drives.enumerated()), id: \.element.id) { index, drive in
                if periodMarker(at: index) {
                    Text(periodLabel(drive.period))
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, index == 0 ? 0 : Spacing.sm)
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

    private func periodLabel(_ period: Int?) -> String {
        guard let period else { return "—" }
        switch period {
        case 1: return "1ST QUARTER"
        case 2: return "2ND QUARTER"
        case 3: return "3RD QUARTER"
        case 4: return "4TH QUARTER"
        case 5: return "OVERTIME"
        default: return "\(period - 4)OT"
        }
    }

    private func driveRow(_ drive: Drive) -> some View {
        HStack(spacing: Spacing.md) {
            LogoImage(url: team(for: drive)?.logoURL)
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

    private func team(for drive: Drive) -> Team? {
        [summary.home, summary.away]
            .compactMap(\.self)
            .first { $0.team.id == drive.teamId }?
            .team
    }

    /// One spoken sentence: "Miami, punt, 5 plays, 20 yards, 2:39".
    /// Internal, not private, so the label shape is unit-testable.
    func accessibilitySummary(for drive: Drive) -> String {
        var parts: [String] = []
        if let location = team(for: drive)?.location { parts.append(location) }
        if let result = drive.result { parts.append(result.lowercased()) }
        if let summary = drive.summary { parts.append(summary) }
        return parts.joined(separator: ", ")
    }
}
