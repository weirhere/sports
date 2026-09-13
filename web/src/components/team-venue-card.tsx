// The Overview tab's Venue card — iOS `TeamVenueCard`: where this team
// plays, and the two facts about the ground the season's own payload can
// honestly carry.
//
// Same shape and same words as the game page's Venue card — the ground's
// name in ink over its city in meta gray (`VenueHeadline`), then
// TeamRecordCard-style label/value pairs beneath a divider.
//
// Deliberately absent: capacity and surface. ESPN publishes no capacity
// anywhere (that is what killed the per-venue request on 2026-09-10), and
// the schedule payload ships neither `grass` nor a venue id to go looking
// with. A row that can never render is worse than no row.

import { CardHeader } from "@/components/card-header";
import { VenueHeadline } from "@/components/venue-headline";
import type { TeamVenue } from "@/lib/types";

export function TeamVenueCard({ venue }: { venue: TeamVenue }) {
  return (
    <section className="card-surface">
      <CardHeader title="Venue" />
      <div className="py-1">
        <VenueHeadline name={venue.name} city={venue.city} />
        <div className="my-1 ml-4 border-t border-divider" />
        {/* The date count is always there — a TeamVenue is built from home
            dates, so there is at least one — and the average joins it once a
            home date has been played, which is what leaves the row
            leading-aligned all preseason. */}
        <div
          className="flex items-center gap-3 px-4 py-[7px]"
          aria-label={crowdSentence(venue)}
        >
          <span aria-hidden="true">
            <Metric
              label="Home games"
              value={venue.homeGames.toLocaleString("en-US")}
            />
          </span>
          {venue.averageAttendance !== undefined && (
            <span aria-hidden="true" className="ml-auto">
              <Metric
                label="Avg. attendance"
                value={venue.averageAttendance.toLocaleString("en-US")}
              />
            </span>
          )}
        </div>
      </div>
    </section>
  );
}

/**
 * The average's denominator is said out loud rather than printed — a sighted
 * reader gets the date count beside it, and a listener would otherwise hear
 * an average over nothing in particular.
 */
export function crowdSentence(venue: TeamVenue): string {
  const parts = [
    `${venue.homeGames} home ${venue.homeGames === 1 ? "game" : "games"}`,
  ];
  if (venue.averageAttendance !== undefined) {
    parts.push(
      `average attendance ${venue.averageAttendance.toLocaleString("en-US")} across ${venue.countedGames} played`
    );
  }
  return parts.join(", ");
}

/** The team-page cards' label/value language: gray label, ink value. */
function Metric({ label, value }: { label: string; value: string }) {
  return (
    <span className="flex items-baseline gap-2">
      <span className="type-row-name text-text-secondary">{label}</span>
      <span className="tnum type-row-name-em text-text-primary">{value}</span>
    </span>
  );
}
