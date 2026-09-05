import SwiftUI

/// One team's line in the standings table: logo, school, then conference
/// and overall records in aligned trailing columns. At accessibility text
/// sizes the columns stop fitting, so the records drop to their own labeled
/// line under the name (GameRow's reflow pattern).
struct ConferenceStandingRow: View {
    let standing: ConferenceStanding
    /// 1-based place in the displayed order — the table's first column
    /// (Andy's ask, 2026-08-25). Nil hides the column.
    var position: Int? = nil
    /// How the team's in-progress game is going, when one is on (Andy,
    /// 2026-08-29): green winning, red losing, gray tied — the movement
    /// pair's colors put to live fortunes. Nil (the usual state) shows
    /// nothing.
    var liveResult: LiveResult? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20
    @ScaledMetric(relativeTo: .subheadline) private var recordWidth: CGFloat = 44
    @ScaledMetric(relativeTo: .subheadline) private var positionWidth: CGFloat = 16

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if isStacked { stackedBody } else { compactBody }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var compactBody: some View {
        HStack(spacing: Spacing.md) {
            positionText
            LogoImage(url: standing.team.logoURL)
                .frame(width: logoSize, height: logoSize)
            Text(standing.team.location)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)
            liveDot
            Spacer(minLength: Spacing.sm)
            recordColumn(standing.conferenceRecord)
            recordColumn(standing.overallRecord)
        }
    }

    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.md) {
                positionText
                LogoImage(url: standing.team.logoURL)
                    .frame(width: logoSize, height: logoSize)
                Text(standing.team.location)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                liveDot
            }
            Text(stackedRecordLine)
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var liveDot: some View {
        if let liveResult {
            Circle()
                .fill(dotColor(liveResult))
                .frame(width: 7, height: 7)
        }
    }

    private func dotColor(_ result: LiveResult) -> Color {
        switch result {
        case .winning: .rankUp
        case .losing: .rankDown
        case .tied: .textSecondary
        }
    }

    private func recordColumn(_ record: String?) -> some View {
        Text(record ?? "–")
            .font(.teamName.monospacedDigit())
            .foregroundStyle(record == nil ? .textSecondary : .textPrimary)
            .frame(minWidth: recordWidth, alignment: .trailing)
    }

    /// The place number, GameRow's rank recipe: weight-emphasized meta,
    /// right-aligned so 1 and 14 share an edge.
    @ViewBuilder
    private var positionText: some View {
        if let position {
            Text("\(position)")
                .font(.metaEmphasis)
                .foregroundStyle(.textSecondary)
                .frame(minWidth: positionWidth, alignment: .trailing)
        }
    }

    private var stackedRecordLine: String {
        [standing.conferenceRecord.map { "Conf \($0)" },
         standing.overallRecord.map { "Overall \($0)" }]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    /// One sentence: "Number 3, Georgia, 7 and 1 in conference, 13 and 2
    /// overall".
    var accessibilitySummary: String {
        var parts = [String]()
        if let position {
            parts.append("Number \(position)")
        }
        parts.append(standing.team.location)
        switch liveResult {
        case .winning: parts.append("playing now, winning")
        case .losing: parts.append("playing now, losing")
        case .tied: parts.append("playing now, tied")
        case nil: break
        }
        if let conference = standing.conferenceRecord {
            parts.append("\(spoken(conference)) \(League.inGroupRecordSpoken(standing.team.league))")
        }
        if let overall = standing.overallRecord {
            parts.append("\(spoken(overall)) overall")
        }
        return parts.joined(separator: ", ")
    }

    /// "7-1" reads as "7 and 1" — a dash alone is swallowed or read as
    /// "minus" depending on the voice.
    private func spoken(_ record: String) -> String {
        record.replacingOccurrences(of: "-", with: " and ")
    }
}
