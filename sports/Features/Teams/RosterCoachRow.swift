import SwiftUI

/// The head coach's line on the Roster tab, in `RosterRow`'s layout so the
/// coach reads as one more person on the roster (Andy, 2026-10-03: "the
/// coach row should be the same format as the players including an
/// avatar"). An empty jersey gutter, the photo or initials in the headshot
/// column, and the role where a player's facts go. No metric column: a
/// coach has no class, age or experience on the roster payload.
///
/// The coordinators under the head coach use it too (2026-10-03), with no
/// photo URL and no link: they come from Wikipedia, which has no ESPN id
/// to fetch a photo or a page with, so they are initials and a role.
struct RosterCoachRow: View {
    let name: String
    let role: String
    var headshotURL: URL? = nil
    var isLink: Bool = false

    // `RosterRow`'s metrics, so the avatar sits in the players' photo column.
    @ScaledMetric(relativeTo: .subheadline) private var jerseyWidth: CGFloat = 24
    @ScaledMetric(relativeTo: .subheadline) private var headshotSize: CGFloat = 36

    var body: some View {
        HStack(spacing: Spacing.md) {
            Color.clear.frame(width: jerseyWidth, height: 1)
            CoachHeadshot(name: name, url: headshotURL, size: headshotSize)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                // Two lines: Wikipedia's roles run long ("Associate head
                // coach/co-defensive coordinator/defensive tackles"), and
                // the half that would truncate is often the position.
                Text(role)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
            }
            .layoutPriority(1)
            Spacer(minLength: Spacing.sm)
            if isLink {
                // `RosterRow`'s chevron, so the two kinds of row on the tab
                // say "this goes somewhere" the same way.
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
