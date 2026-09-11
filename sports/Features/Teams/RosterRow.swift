import SwiftUI

/// One player's line on the Roster tab: jersey gutter, headshot, name over
/// the facts about them, and the one metric column this league keeps.
///
/// FotMob's squad row, in the standings tables' own metrics — the gutter is
/// `ConferenceStandingRow`'s place column and the trailing column follows
/// `StandingsColumn`'s scaled-width convention, so the two tables in the app
/// read as one language.
///
/// Not a link. There is no player page anywhere in the app, and a row that
/// looks tappable promises one.
struct RosterRow: View {
    let player: RosterPlayer
    let league: League

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var jerseyWidth: CGFloat = 24
    @ScaledMetric(relativeTo: .subheadline) private var headshotSize: CGFloat = 36
    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    private var metric: RosterMetric { league.rosterMetric }
    private var metricValue: String? { player.metricValue(for: league) }

    /// Position, height, weight — and an injury designation where ESPN ships
    /// one (the NFL's, and only for the handful carrying it). Each part drops
    /// out on its own, so a row with none of them is just a name.
    private var metaLine: String {
        [player.position, player.height, player.weight, player.injuryStatus]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// At accessibility sizes the metric column stops fitting beside the name,
    /// so it joins the meta line — `ConferenceStandingRow`'s reflow.
    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        HStack(spacing: Spacing.md) {
            jerseyText
            headshot
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                if !stackedMetaLine.isEmpty {
                    Text(stackedMetaLine)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(isStacked ? 2 : 1)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: Spacing.sm)
            if !isStacked {
                Text(metricValue ?? "—")
                    .font(.teamName.monospacedDigit())
                    .foregroundStyle(metricValue == nil ? Color.textSecondary : Color.textPrimary)
                    .frame(minWidth: metric.width * scale, alignment: .trailing)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var stackedMetaLine: String {
        guard isStacked, let metricValue else { return metaLine }
        let spoken = metric.spoken(metricValue)
        return metaLine.isEmpty ? spoken : metaLine + " · " + spoken
    }

    /// The number labels the row; the name is its subject, so the number sits
    /// in the quieter ink. Monospaced so a column of them lines up, and blank
    /// where ESPN ships no jersey (5 of 76 NFL players, 10 of 18 NBA ones in
    /// preseason) rather than inventing a dash.
    private var jerseyText: some View {
        Text(player.jersey ?? "")
            .font(.teamName.monospacedDigit())
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
            .frame(minWidth: jerseyWidth, alignment: .trailing)
    }

    /// The player photo cropped into a quiet disc — the Leaders card's
    /// treatment, at row scale. A player with no headshot keeps the disc, so
    /// the names stay in one column.
    private var headshot: some View {
        LogoImage(url: player.thumbnailURL, placeholder: nil, contentMode: .fill)
            .frame(width: headshotSize, height: headshotSize)
            .background(Circle().fill(Color.bgElevated))
            .clipShape(Circle())
    }

    /// One sentence: "12, Patrick Mahomes, Quarterback, age 30". The position
    /// is spoken in full — "QB" is read as letters, and a roster is exactly
    /// the place a listener is learning who these people are.
    private var accessibilitySummary: String {
        var parts: [String] = []
        if let jersey = player.jersey { parts.append("Number \(jersey)") }
        parts.append(player.name)
        if let position = player.positionName ?? player.position { parts.append(position) }
        if let height = player.height { parts.append(height) }
        if let weight = player.weight { parts.append(weight) }
        if let metricValue { parts.append(metric.spoken(metricValue)) }
        if let injury = player.injuryStatus { parts.append(injury) }
        return parts.joined(separator: ", ")
    }
}
