import SwiftUI

/// The Overview tab's Venue card: where this team plays, and the two facts
/// about the ground that the season's own payload can honestly carry.
///
/// Same shape and same words as the game page's Venue card — the ground's
/// name in ink over its city in meta gray (`VenueHeadline`), then
/// `TeamRecordCard`-style label/value pairs beneath a divider.
///
/// What is deliberately absent: **capacity and surface**. ESPN publishes no
/// capacity anywhere (that is what killed the per-venue request on
/// 2026-09-10), and the schedule payload ships neither `grass` nor a venue
/// `id` to go looking with. A row that can never render is worse than no
/// row, which is the whole lesson of that fetch.
struct TeamVenueCard: View {
    let venue: TeamVenue

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: "Venue")
            VenueHeadline(name: venue.name, city: venue.city)
                .padding(.top, Spacing.xs)
            Divider().overlay(Color.divider)
                .padding(.leading, Spacing.lg)
                .padding(.vertical, Spacing.xs)
            crowdRow
        }
        .padding(.bottom, Spacing.xs)
    }

    /// The pair below the divider. The date count is always there — a
    /// `TeamVenue` is built from home dates, so there is at least one —
    /// and the average joins it once a home date has been played, which
    /// is what leaves the row leading-aligned all preseason.
    private var crowdRow: some View {
        HStack(spacing: Spacing.md) {
            metric("Home games", venue.homeGames.formatted())
            Spacer(minLength: Spacing.sm)
            if let average = venue.averageAttendance {
                metric("Avg. attendance", average.formatted())
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(crowdAccessibilityLabel)
    }

    /// The team-page cards' label/value language: gray label, ink value.
    private func metric(_ label: String, _ value: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(label)
                .font(.rowName)
                .foregroundStyle(.textSecondary)
            Text(value)
                .font(.rowNameEmphasis)
                .monospacedDigit()
                .foregroundStyle(.textPrimary)
        }
    }

    /// The average's denominator is said out loud here rather than printed
    /// — a sighted reader gets "7" beside it, and a listener would
    /// otherwise hear an average over nothing in particular.
    private var crowdAccessibilityLabel: String {
        var parts = ["\(venue.homeGames) home \(venue.homeGames == 1 ? "game" : "games")"]
        if let average = venue.averageAttendance {
            parts.append("average attendance \(average.formatted()) across \(venue.countedGames) played")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    VStack(spacing: Spacing.sm) {
        TeamVenueCard(venue: TeamVenue(name: "Sanford Stadium", city: "Athens, GA",
                                       homeGames: 7, countedGames: 7,
                                       averageAttendance: 93_033))
            .cardSurface()
        TeamVenueCard(venue: TeamVenue(name: "Lumen Field", city: "Seattle, WA",
                                       homeGames: 9, countedGames: 0,
                                       averageAttendance: nil))
            .cardSurface()
    }
    .padding(Spacing.sm)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.bgRecessed)
}
