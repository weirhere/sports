"use client";

// The scores page's left rail — the follow set as two card lists, teams
// then conferences, each row a link to that entity's page (FotMob's
// "Followed teams" / "Followed leagues" column).
//
// Desktop only. On a phone the slate's own Following section already
// answers "where are my teams", and a rail above it would push the games
// below the fold — the one thing the Saturday sort order can't afford.
//
// Reading only: the star that follows and unfollows lives on the pages
// this rail links to. A rail that could empty itself under the pointer is
// a rail that moves the row you were aiming at.

import { useMemo } from "react";
import Link from "next/link";
import { Star } from "lucide-react";
import { CardHeader } from "@/components/card-header";
import { ConferenceLogo } from "@/components/theme/conference-logo";
import { TeamLogo } from "@/components/team-logo";
import { Skeleton } from "@/components/ui/skeleton";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { useTeamDirectory } from "@/lib/hooks/use-team-directory";
import { conferenceLogoUrlFor, conferenceNameFor } from "@/lib/conferences";
import {
  conferenceToken,
  followedLeagues,
  followKey,
  parseConferenceToken,
  parseFollowKey,
  type ConferenceRef,
} from "@/lib/refs";
import { conferencePath, teamPath } from "@/lib/routes";
import type { Team } from "@/lib/types";

export function FollowingSidebar() {
  const {
    favorites,
    favoriteConferences,
    isLoaded: favoritesLoaded,
  } = useFavoritesContext();
  // Every league the follow set actually touches, not the slate's one:
  // the slate spans all four now, so a college-football-only directory
  // would drop a followed NFL team rather than name it. A set that only
  // holds college teams still costs exactly one request.
  const leagues = useMemo(() => followedLeagues(favorites), [favorites]);
  const { conferences, isLoading: directoryLoading } =
    useTeamDirectory(leagues);

  // The follow set is league-qualified keys; the directory is what turns
  // one into a name. Until it lands the rows are skeletons, never a key.
  const teamsByKey = new Map<string, Team>();
  for (const conference of conferences) {
    for (const team of conference.teams) {
      teamsByKey.set(followKey({ league: team.league, teamId: team.id }), team);
    }
  }

  // Re-spelling each stored value through its parser is what collapses two
  // spellings of one follow into one row — a pre-axis bare id and its
  // qualified twin name the same team, and the rail must not list it twice.
  const followedTeams = dedupe(
    favorites.map(parseFollowKey).filter(isPresent).map(followKey)
  )
    .map((key) => teamsByKey.get(key))
    .filter(isPresent);

  // A followed team the directory can't name — another league's, until the
  // scope widens, or a school that left the division — drops out rather
  // than showing a key. With none left the card goes too: a headed card
  // over an empty list says the rail is broken.
  const teamsVisible =
    favorites.length > 0 && (directoryLoading || followedTeams.length > 0);

  const followedConferences = dedupeRefs(
    favoriteConferences.map(parseConferenceToken).filter(isPresent)
  );

  // Pre-hydration the rail is an empty column of the same width, so the
  // slate beside it never shifts once the follow set arrives.
  const empty =
    favoritesLoaded &&
    favorites.length === 0 &&
    favoriteConferences.length === 0;

  return (
    <aside
      aria-label="Following"
      className="hidden lg:sticky lg:top-[7.5rem] lg:block lg:self-start"
    >
      <div className="flex flex-col gap-3">
        {teamsVisible && (
          <section className="card-surface">
            <CardHeader title="Following teams" />
            {directoryLoading && followedTeams.length === 0 ? (
              <SkeletonRows count={favorites.length} />
            ) : (
              <ul className="py-1">
                {followedTeams.map((team) => (
                  <li key={followKey({ league: team.league, teamId: team.id })}>
                    <Link
                      href={teamPath(team)}
                      className="flex items-center gap-3 px-3 py-[7px] transition-colors hover:bg-bg-header"
                    >
                      {/* Decorative — the row's text carries the name. */}
                      <TeamLogo team={team} teamName="" size="sm" />
                      <span className="truncate type-team-name text-text-primary">
                        {team.school}
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </section>
        )}

        {followedConferences.length > 0 && (
          <section className="card-surface">
            <CardHeader title="Following conferences" />
            <ul className="py-1">
              {followedConferences.map((ref) => (
                <li key={conferenceToken(ref)}>
                  <Link
                    href={conferencePath(ref)}
                    className="flex items-center gap-3 px-3 py-[7px] transition-colors hover:bg-bg-header"
                  >
                    <ConferenceLogo src={conferenceLogoUrlFor(ref)} name="" />
                    <span className="truncate type-team-name text-text-primary">
                      {conferenceNameFor(ref)}
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          </section>
        )}

        {empty && <EmptyRail />}
      </div>
    </aside>
  );
}

/**
 * Nothing followed yet: say what the rail is for, and open the door. This
 * is the desktop half of the slate's own `FollowPromptCard`, which hides
 * itself at this width so the screen only asks once.
 */
function EmptyRail() {
  return (
    <section className="card-surface p-4">
      <div className="flex items-center gap-2">
        <Star aria-hidden="true" className="h-4 w-4 text-text-secondary" />
        <h2 className="type-team-name-em text-text-primary">Following</h2>
      </div>
      <p className="mt-1 type-meta text-text-secondary">
        Follow a team or a conference and it lives here, on every slate.
      </p>
      <div className="mt-3 flex gap-4">
        <Link
          href="/teams"
          className="type-meta-em text-text-primary hover:underline"
        >
          Browse teams
        </Link>
        <Link
          href="/rankings"
          className="type-meta-em text-text-primary hover:underline"
        >
          Browse conferences
        </Link>
      </div>
    </section>
  );
}

function SkeletonRows({ count }: { count: number }) {
  return (
    <ul className="py-1">
      {Array.from({ length: count }).map((_, i) => (
        <li key={i} className="flex items-center gap-3 px-3 py-[7px]">
          <Skeleton className="h-6 w-6 rounded-full" />
          <Skeleton className="h-4 w-28" />
        </li>
      ))}
    </ul>
  );
}

function isPresent<T>(value: T | undefined): value is T {
  return value !== undefined;
}

/** First-wins dedupe — the follow set's own order is the rail's order. */
function dedupe(keys: string[]): string[] {
  return [...new Set(keys)];
}

function dedupeRefs(refs: ConferenceRef[]): ConferenceRef[] {
  const seen = new Set<string>();
  return refs.filter((ref) => {
    const token = conferenceToken(ref);
    if (seen.has(token)) return false;
    seen.add(token);
    return true;
  });
}
