import SwiftUI

/// The venue block both Venue cards lead with: the ground's name in ink
/// over its city in meta gray, behind a pin in the icon gutter (FotMob's
/// treatment, adopted on the game page 2026-09-06).
///
/// Shared so a team's home ground and the ground a game is played at read
/// as the same fact in the same words — they are the same fact.
///
/// **Tapping it opens the ground in Apple Maps** (COR-151, 2026-11-07).
/// Apple Maps directly rather than a chooser: iOS has no default-maps
/// setting outside the EU, and a chooser would need
/// `LSApplicationQueriesSchemes` for apps nobody has asked for. ESPN sends
/// a name and a city and no coordinates, so it is a search (`MapsLink`),
/// which Maps answers well for a real arena. The trailing arrow is the
/// system's "this leaves the app" mark; a chevron would promise a pushed
/// page.
struct VenueHeadline: View {
    let name: String
    let city: String?

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url = MapsLink.url(name: name, city: city) {
            Button { openURL(url) } label: { content(opensMaps: true) }
                .buttonStyle(.plain)
                .accessibilityHint("Opens in Maps")
        } else {
            content(opensMaps: false)
        }
    }

    private func content(opensMaps: Bool) -> some View {
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
            if opensMaps {
                // Top-aligned with the name line, like the pin opposite it.
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.textSecondary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
        // The whole row is the target, not just the glyphs.
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: Spacing.sm) {
        VenueHeadline(name: "Benchmark International Arena", city: "Tampa, FL")
            .cardSurface()
        VenueHeadline(name: "Sanford Stadium", city: nil)
            .cardSurface()
    }
    .padding(Spacing.sm)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.bgRecessed)
}
