"use client";

// One player's page — iOS `PlayerPage` (Features/Players/).
//
// **One tab, so no tab row.** The design settled on four — Profile, Games,
// Stats, Career — and three of them have no confirmed data source (E20's P0).
// The app's own rule decides what to do about that rather than a new one: an
// empty roster shows "Roster TBA" instead of a tab, and game detail hides its
// whole tab row when there is no box score. Three dead tabs would promise
// pages that don't exist, which is the mistake the unlinked roster rows were
// avoiding in the first place. `HeroHeader` renders exactly this when it is
// handed no `tabs`.

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { CardHeader } from "@/components/card-header";
import { HeroHeader } from "@/components/hero-header";
import type { League } from "@/lib/leagues";
import { teamPath } from "@/lib/routes";
import {
  playerMetaLine,
  playerProfileRows,
  playerSpokenSummary,
} from "@/lib/player-profile";
import type { RosterPlayer } from "@/lib/types";

interface PlayerViewProps {
  league: League;
  player: RosterPlayer;
  teamId: string;
  teamName?: string;
  teamLogoUrl?: string;
}

export function PlayerView({
  league,
  player,
  teamId,
  teamName,
  teamLogoUrl,
}: PlayerViewProps) {
  const rows = playerProfileRows(player, league);
  // The team is a badge of its own now, so the line beside it is the rest:
  // `playerMetaLine` handed no team name returns exactly "#2 · WR".
  const meta = playerMetaLine(player);
  // No team name means the schedule fetch failed, and a badge with no team
  // in it is a link to nowhere. The line keeps every part it has instead.
  const hasBadge = Boolean(teamName);

  return (
    <>
      {/* The hero speaks one sentence; the parts below it are decoration,
          the way a roster row's captions are. */}
      <span className="sr-only">{playerSpokenSummary(player, teamName)}</span>
      <HeroHeader
        logo={<Headshot player={player} />}
        title={player.name}
        subtitle={
          hasBadge || meta ? (
            <div className="flex min-w-0 items-center gap-1.5">
              {/* The team is the one part of this line that goes somewhere,
                  so it is the one part that looks like it does: a badge on
                  the elevated ground, crest and name together. The rest of
                  the line stays quiet text beside it.

                  It is deliberately **not** inside the `aria-hidden` the
                  rest of the line carries. A focusable element hidden from
                  the accessibility tree is reachable by keyboard and
                  invisible to a screen reader, which is worse than the
                  duplication it would have saved. */}
              {hasBadge && (
                <Link
                  href={teamPath({ league, id: teamId })}
                  className="flex min-w-0 shrink items-center gap-1.5 rounded-full bg-bg-elevated py-1 pl-1 pr-2.5 type-chip-em text-text-secondary transition-colors hover:text-text-primary focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-text-secondary"
                >
                  {teamLogoUrl && (
                    <Image
                      src={teamLogoUrl}
                      alt=""
                      width={16}
                      height={16}
                      unoptimized
                      className="h-4 w-4 shrink-0 object-contain"
                    />
                  )}
                  <span className="truncate">{teamName}</span>
                  <span className="sr-only">, view team page</span>
                </Link>
              )}
              {meta && (
                <span
                  aria-hidden="true"
                  className="truncate type-meta text-text-secondary"
                >
                  {meta}
                </span>
              )}
            </div>
          ) : undefined
        }
      />

      {rows.length > 0 && (
        <section className="card-surface mt-4 pb-1">
          <CardHeader title="Profile" />
          {rows.map((row, index) => (
            <div key={row.label}>
              {index > 0 && <div className="ml-4 border-t border-divider" />}
              <div
                className="flex items-center justify-between gap-2 px-4 py-3"
                aria-label={`${row.label} ${row.value}`}
              >
                <span
                  aria-hidden="true"
                  className="type-row-name text-text-secondary"
                >
                  {row.label}
                </span>
                <span
                  aria-hidden="true"
                  className="tnum type-row-name-em text-text-primary"
                >
                  {row.value}
                </span>
              </div>
            </div>
          ))}
        </section>
      )}
    </>
  );
}

/**
 * The full press photo, which is the one place in the app it is the right
 * asset: a roster shows a hundred of these discs and asks the CDN combiner
 * for thumbnails, a page shows one.
 */
function Headshot({ player }: { player: RosterPlayer }) {
  const [failed, setFailed] = useState(false);

  return (
    <span
      aria-hidden="true"
      className="flex h-14 w-14 shrink-0 overflow-hidden rounded-full bg-bg-elevated"
    >
      {player.headshotUrl && !failed && (
        <Image
          src={player.headshotUrl}
          alt=""
          width={56}
          height={56}
          unoptimized
          onError={() => setFailed(true)}
          className="h-full w-full object-cover"
        />
      )}
    </span>
  );
}
