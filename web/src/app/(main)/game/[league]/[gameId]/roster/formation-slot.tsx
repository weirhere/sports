"use client";

// One player on the formation (iOS `FormationSlot`): the disc, and
// "12 Mahomes" under it. A link to the player's page, like every other name
// in the app since E20.

import Link from "next/link";
import type { League } from "@/lib/leagues";
import type { Team } from "@/lib/types";
import type { GameRosterPerson } from "@/lib/game-roster";
import { playerHref } from "@/lib/player-profile";
import { PersonDisc } from "./person-disc";
import { inkAlpha } from "./surface-ink";

export function FormationSlot({
  person,
  team,
  league,
  ink,
  maxWidth,
}: {
  person: GameRosterPerson;
  team: Team;
  league: League;
  /** The name's color on the surface — see `surfaceInk`. */
  ink: string;
  /**
   * A ceiling for a wing, so it holds the edge rather than spreading into
   * the field; undefined shares the row evenly. A ceiling and not a fixed
   * width because five wings at a fixed width overflowed the field.
   */
  maxWidth?: number;
}) {
  const label = [person.jersey, person.shortName].filter(Boolean).join(" ");
  const spoken = [
    person.jersey ? `Number ${person.jersey}` : undefined,
    person.name,
    person.positionName ?? person.position,
  ]
    .filter((part): part is string => Boolean(part))
    .join(", ");
  return (
    <Link
      href={playerHref(league, team.id, person.id)}
      aria-label={spoken}
      className="flex min-w-0 flex-1 flex-col items-center gap-0.5 px-px focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-current"
      style={{ maxWidth, color: ink }}
    >
      <PersonDisc
        jersey={person.jersey}
        headshotUrl={person.headshotUrl}
        size={32}
        // A hairline of the surface's own ink, translucent, so the disc
        // stands off ice it shares a gray with without a pure-white ring on
        // turf (Andy, 2026-10-18).
        style={{ boxShadow: `inset 0 0 0 1px ${inkAlpha(ink, 0.35)}` }}
      />
      <span
        aria-hidden="true"
        className="block w-full truncate text-center text-[11px] font-medium leading-tight tnum"
      >
        {label}
      </span>
    </Link>
  );
}
