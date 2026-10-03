import SwiftUI

/// A person's page title once the hero has scrolled under the bar: the
/// name over the club, centered in the bar's principal slot (Andy,
/// 2026-10-03, from FotMob's player page). TeamPage and ConferencePage
/// carry one line because the page *is* the team; a player's page needs
/// the club to say whose player this is.
struct CollapsedTitle: View {
    let title: String
    var subtitle: String?
    /// The header's color in light mode; nil is the monochrome bar.
    var paint: HeaderPaint?

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(paint?.ink ?? .textPrimary)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(paint?.secondaryInk ?? .textSecondary)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}
