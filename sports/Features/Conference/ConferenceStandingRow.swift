import SwiftUI

/// One team's line in the standings table: logo, school, then whichever
/// numeric columns the league keeps, in aligned trailing columns. At
/// accessibility text sizes the columns stop fitting, so they drop to
/// their own labeled line under the name (GameRow's reflow pattern).
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
    /// True for the rows above a conference's championship cut. The bar
    /// beside them is decorative, so the fact has to live in the sentence
    /// too — VoiceOver reads no edges.
    var qualifies: Bool = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20
    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1
    @ScaledMetric(relativeTo: .subheadline) private var positionWidth: CGFloat = 16

    /// Mirrors `StandingsColumnCaptions` — the numbers have to sit under
    /// the captions promising them.
    private var columns: [StandingsColumn] { standing.team.league.standingsColumns }

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
            ForEach(columns) { column in
                recordColumn(standing.value(for: column), width: column.width)
            }
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

    private func recordColumn(_ value: String?, width: CGFloat) -> some View {
        Text(value ?? "–")
            .font(.teamName.monospacedDigit())
            .foregroundStyle(value == nil ? .textSecondary : .textPrimary)
            .frame(minWidth: width * scale, alignment: .trailing)
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
        columns
            .compactMap { column in
                standing.value(for: column).map { "\(column.caption) \($0)" }
            }
            .joined(separator: " · ")
    }

    /// One sentence, in whatever columns the league keeps: "Number 3,
    /// Georgia, 7 and 1 in conference, 13 and 2 overall" — or "Number 1,
    /// Carolina, 82 games played, 53 and 22 and 7 and overtime losses, 113
    /// points".
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
        for column in columns {
            guard let value = standing.value(for: column) else { continue }
            parts.append("\(spoken(value)) \(column.spoken)")
        }
        if qualifies { parts.append("in the championship game") }
        return parts.joined(separator: ", ")
    }

    /// "7-1" reads as "7 and 1" — a dash alone is swallowed or read as
    /// "minus" depending on the voice.
    private func spoken(_ record: String) -> String {
        record.replacingOccurrences(of: "-", with: " and ")
    }
}
