// The venue block both Venue cards lead with — iOS `VenueHeadline`: the
// ground's name in ink over its city in meta gray, behind a pin in the icon
// gutter (FotMob's treatment, adopted on the game page 2026-09-06).
//
// Shared so a team's home ground and the ground a game is played at read as
// the same fact in the same words — they are the same fact.

import { MapPin } from "lucide-react";

export function VenueHeadline({
  name,
  city,
}: {
  name: string;
  city?: string;
}) {
  return (
    <div className="flex items-start gap-3 px-4 py-[7px]">
      <MapPin
        aria-hidden="true"
        className="mt-0.5 h-4 w-5 shrink-0 text-text-secondary"
      />
      <div className="min-w-0">
        <p className="type-team-name-em text-text-primary">{name}</p>
        {city && <p className="type-meta text-text-secondary">{city}</p>}
      </div>
    </div>
  );
}
