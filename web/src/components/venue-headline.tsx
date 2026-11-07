// The venue block both Venue cards lead with — iOS `VenueHeadline`: the
// ground's name in ink over its city in meta gray, behind a pin in the icon
// gutter (FotMob's treatment, adopted on the game page 2026-09-06).
//
// Shared so a team's home ground and the ground a game is played at read as
// the same fact in the same words — they are the same fact.
//
// **The whole block links to the ground in Apple Maps** (COR-151,
// 2026-11-07), in a new tab. The trailing arrow is the "this leaves the
// site" mark; a chevron would promise a page of ours.

import { ArrowUpRight, MapPin } from "lucide-react";
import { mapsLink } from "@/lib/maps-link";

export function VenueHeadline({
  name,
  city,
}: {
  name: string;
  city?: string;
}) {
  const href = mapsLink(name, city);
  const content = (
    <>
      <MapPin
        aria-hidden="true"
        className="mt-0.5 h-4 w-5 shrink-0 text-text-secondary"
      />
      <div className="min-w-0">
        <p className="type-team-name-em text-text-primary">{name}</p>
        {city && <p className="type-meta text-text-secondary">{city}</p>}
      </div>
      {href && (
        <ArrowUpRight
          aria-hidden="true"
          className="mt-0.5 ml-auto h-4 w-4 shrink-0 text-text-secondary"
        />
      )}
    </>
  );
  const className = "flex items-start gap-3 px-4 py-[7px]";
  if (!href) return <div className={className}>{content}</div>;
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`${[name, city].filter(Boolean).join(", ")}, opens in Maps`}
      className={`${className} transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none`}
    >
      {content}
    </a>
  );
}
