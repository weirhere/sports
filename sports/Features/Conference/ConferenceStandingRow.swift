import SwiftUI

/// The identity half of a standings row: place, mark, school, and the dot
/// that says the team is playing right now.
///
/// Its own view because a wide table pins it while the numbers beside it
/// scroll (`StandingsList`), and the two layouts must draw the same cell.
/// `width` is that pinned column's; nil lets the name take what's left,
/// which is what every table narrow enough to fit does.
struct StandingsIdentityCell: View {
    let standing: ConferenceStanding
    var position: Int? = nil
    var liveResult: LiveResult? = nil
    /// Fixed width for the pinned column; nil to size to the row.
    var width: CGFloat? = nil

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 20
    @ScaledMetric(relativeTo: .subheadline) private var positionWidth: CGFloat = 16

    var body: some View {
        // The fixed frame only where there is one: `.frame(width: nil)`
        // is not reliably transparent to the Spacer's flexibility, and in
        // the whole-row layout the name column is what stretches.
        if let width {
            content.frame(width: width, alignment: .leading)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: Spacing.md) {
            if let position {
                // The place number, GameRow's rank recipe: weight-emphasized
                // meta, right-aligned so 1 and 14 share an edge.
                Text("\(position)")
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
                    .frame(minWidth: positionWidth, alignment: .trailing)
            }
            LogoImage(url: standing.team.logoURL)
                .frame(width: logoSize, height: logoSize)
            Text(standing.team.location)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)
            if let liveResult {
                Circle()
                    .fill(Self.dotColor(liveResult))
                    .frame(width: 7, height: 7)
            }
            Spacer(minLength: width == nil ? Spacing.sm : 0)
        }
    }

    static func dotColor(_ result: LiveResult) -> Color {
        switch result {
        case .winning: .rankUp
        case .losing: .rankDown
        case .tied: .textSecondary
        }
    }
}

/// The numeric half: one right-aligned column per stat the league keeps,
/// under the captions promising them. A stat the payload didn't carry
/// shows a dash rather than dropping the column — the grid has to hold.
struct StandingsNumbersCell: View {
    let standing: ConferenceStanding
    let columns: [StandingsColumn]

    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(columns) { column in
                let value = standing.value(for: column)
                Text(value ?? "–")
                    .font(.teamName.monospacedDigit())
                    .foregroundStyle(value == nil ? .textSecondary : .textPrimary)
                    .frame(minWidth: column.width * scale, alignment: .trailing)
            }
        }
    }
}

/// One team's line in the standings table: logo, school, then whichever
/// numeric columns the league keeps, in aligned trailing columns. At
/// accessibility text sizes the columns stop fitting, so they drop to
/// their own labeled line under the name (GameRow's reflow pattern).
///
/// This is the whole-row form, for tables narrow enough to need no pinned
/// column. The NFL's is not — `StandingsList` composes the two cells above
/// itself there.
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
    /// Overrides the league's own column set. The game page's matchup
    /// slice passes the compact pair, which is what keeps a two-row card
    /// from becoming a twelve-column scroller.
    var columns: [StandingsColumn]? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Mirrors `StandingsColumnCaptions` — the numbers have to sit under
    /// the captions promising them.
    private var shownColumns: [StandingsColumn] {
        columns ?? standing.team.league.standingsColumns
    }

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
            StandingsIdentityCell(standing: standing, position: position,
                                  liveResult: liveResult)
            StandingsNumbersCell(standing: standing, columns: shownColumns)
        }
    }

    private var stackedBody: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            StandingsIdentityCell(standing: standing, position: position,
                                  liveResult: liveResult)
            Text(StandingsSentence.stackedLine(standing, columns: shownColumns))
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One sentence, in whatever columns the league keeps: "Number 3,
    /// Georgia, 7 and 1 in conference, 13 and 2 overall" — or "Number 1,
    /// Carolina, 82 games played, 53 and 22 and 7 and overtime losses, 113
    /// points".
    var accessibilitySummary: String {
        StandingsSentence.spoken(standing, columns: shownColumns,
                                 position: position, liveResult: liveResult,
                                 qualifies: qualifies)
    }
}

/// What a standings row says — out loud, and on the labeled line it falls
/// back to at accessibility text sizes. Shared so the pinned-column table
/// and the whole-row one speak identically.
enum StandingsSentence {
    static func stackedLine(_ standing: ConferenceStanding,
                            columns: [StandingsColumn]) -> String {
        columns
            .compactMap { column in
                standing.value(for: column).map { "\(column.caption) \($0)" }
            }
            .joined(separator: " · ")
    }

    static func spoken(_ standing: ConferenceStanding,
                       columns: [StandingsColumn],
                       position: Int?,
                       liveResult: LiveResult?,
                       qualifies: Bool) -> String {
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
            guard let value = standing.value(for: column),
                  // ESPN's own "nothing here yet" — the leader's games
                  // back, a 0-0 team's streak. A dash spoken is noise.
                  value != "-" else { continue }
            parts.append("\(phrase(value, for: column)) \(column.spoken)")
        }
        if qualifies { parts.append("in the championship game") }
        return parts.joined(separator: ", ")
    }

    /// "7-1" reads as "7 and 1" — a dash alone is swallowed or read as
    /// "minus" depending on the voice. Only records get that treatment: a
    /// differential's "-12" means minus, and saying "and 12" would invert
    /// it.
    private static func phrase(_ value: String, for column: StandingsColumn) -> String {
        if column.field == .streak {
            // "W3" is a table's shorthand, not a sentence. Spelled out
            // here because the letter and the number run together in
            // every voice that reads it.
            let count = value.dropFirst()
            switch value.first {
            case "W": return "won \(count)"
            case "L": return "lost \(count)"
            default: return value
            }
        }
        guard column.field.isRecord else { return value }
        return value.replacingOccurrences(of: "-", with: " and ")
    }
}
