import SwiftUI

/// One of a school's pros on the Pros tab (2026-11-02): headshot, name, and
/// a meta line of position and the pro team with its mark.
///
/// `RosterRow`'s density and disc, without the jersey gutter or the metric
/// column: a school's pros span three leagues and thirty-odd teams, so a
/// jersey number says nothing here and no one metric fits them all. The
/// team is what the row is for — where they went.
struct ProAlumnusRow: View {
    let alumnus: ProAlumnus
    /// The pro team, resolved through the directory; nil leaves the meta
    /// line to the position.
    let team: Team?

    @ScaledMetric(relativeTo: .subheadline) private var headshotSize: CGFloat = 36
    @ScaledMetric(relativeTo: .caption) private var markSize: CGFloat = 14

    private var teamName: String? {
        team?.shortDisplayName ?? team?.displayName ?? team?.location
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            headshot
            VStack(alignment: .leading, spacing: 2) {
                Text(alumnus.name)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                metaLine
            }
            .layoutPriority(1)
            Spacer(minLength: Spacing.sm)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// "QB · [mark] Patriots" — each part drops out on its own.
    @ViewBuilder
    private var metaLine: some View {
        if alumnus.position != nil || teamName != nil {
            HStack(spacing: Spacing.xs) {
                if let position = alumnus.position {
                    Text(position)
                    if teamName != nil { Text("·") }
                }
                if let teamName {
                    if let logo = team?.logoURL {
                        LogoImage(url: logo)
                            .frame(width: markSize, height: markSize)
                    }
                    Text(teamName)
                }
            }
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
        }
    }

    /// `RosterRow`'s disc, so a school's pros and a team's roster read as
    /// the same table.
    private var headshot: some View {
        LogoImage(url: alumnus.thumbnailURL, placeholder: nil, contentMode: .fill)
            .frame(width: headshotSize, height: headshotSize)
            .background(Circle().fill(Color.bgElevated))
            .clipShape(Circle())
    }

    /// "Drake Maye, Quarterback, New England Patriots" — the position in
    /// full, `RosterRow`'s reason.
    private var accessibilitySummary: String {
        var parts = [alumnus.name]
        if let position = alumnus.positionName ?? alumnus.position { parts.append(position) }
        if let name = team?.displayName ?? teamName { parts.append(name) }
        return parts.joined(separator: ", ")
    }
}
