import SwiftUI

/// The venue block both Venue cards lead with: the ground's name in ink
/// over its city in meta gray, behind a pin in the icon gutter (FotMob's
/// treatment, adopted on the game page 2026-09-06).
///
/// Shared so a team's home ground and the ground a game is played at read
/// as the same fact in the same words — they are the same fact.
struct VenueHeadline: View {
    let name: String
    let city: String?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.textSecondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
                if let city {
                    Text(city)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }
}
