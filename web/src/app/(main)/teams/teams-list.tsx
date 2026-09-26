"use client";

// The teams you follow, one card each — the web twin of iOS `TeamsScreen`.
//
// It used to be the whole directory in accordions: every conference, every
// team, ~250 rows deep. Browsing by conference is what the Leagues hub is
// for, and finding one team by name is what search is for; what this tab is
// for is the handful of teams that are yours (iOS, 2026-09-05). Adding one is
// a sheet away.

import { useMemo, useState } from "react";
import Link from "next/link";
import { ChevronRight, Plus, Star } from "lucide-react";
import { AddTeamsSheet } from "@/components/add-teams-sheet";
import { PageHeader } from "@/components/page-header";
import { TeamLogo } from "@/components/team-logo";
import { Skeleton } from "@/components/ui/skeleton";
import { useTeamDirectory } from "@/lib/hooks/use-team-directory";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { LEAGUES } from "@/lib/leagues";
import { followedLeagues, followKey, type FollowKey } from "@/lib/refs";
import { teamPath } from "@/lib/routes";
import { teamFullName, teamSpokenLabel, teamSubtitle } from "@/lib/team-name";
import type { Team } from "@/lib/types";

export function TeamsList() {
  const { favorites } = useFavoritesContext();
  const [isAdding, setIsAdding] = useState(false);

  // The follow list needs only the leagues it actually holds; the sheet
  // needs all four, and only once it opens — so a college-football-only user
  // never pays for three extra requests to look at their own teams.
  const followed = useMemo(() => followedLeagues(favorites), [favorites]);
  const own = useTeamDirectory(followed);
  const all = useTeamDirectory(isAdding ? LEAGUES : followed);

  const followedSet = useMemo(() => new Set(favorites), [favorites]);
  const teams = useMemo(() => {
    const seen = new Set<string>();
    return own.conferences
      .flatMap((conference) => conference.teams)
      .filter((team) => {
        const key = followKey({ league: team.league, teamId: team.id });
        if (!followedSet.has(key) || seen.has(key)) return false;
        seen.add(key);
        return true;
      })
      .sort((a, b) => a.school.localeCompare(b.school));
  }, [own.conferences, followedSet]);

  // A follow can't be rendered as a card until the directory says who it is,
  // so the load state stands in for the whole list — the empty state must
  // never be shown to someone who follows teams.
  const loading = favorites.length > 0 && teams.length === 0 && own.isLoading;

  return (
    <>
      {/* The root tabs' one masthead (iOS `PageHeader`, 2026-09-21), with
          the plus in the slot the Games tab's controls occupy. */}
      <PageHeader
        title="Teams"
        trailing={
          // The plus keeps its circle (iOS, 2026-09-21), so it reads as a
          // control and not a stray glyph. The card's surface rather than
          // `bg-elevated`, which is the page ground's own gray in light
          // and would draw no circle at all. The card at the list's foot
          // is the invitation; this is the one that's always in reach.
          <button
            type="button"
            onClick={() => setIsAdding(true)}
            aria-label="Add teams"
            className="flex h-11 w-11 items-center justify-center rounded-full bg-bg-card text-text-primary shadow-card transition-colors hover:bg-bg-header"
          >
            <Plus aria-hidden="true" className="h-4 w-4" />
          </button>
        }
      />
      <div className="flex flex-col gap-2">
        {loading ? (
          [0, 1, 2].map((row) => (
            <Skeleton key={row} className="h-[72px] w-full rounded-[10px]" />
          ))
        ) : teams.length === 0 ? (
          <EmptyState />
        ) : (
          teams.map((team) => (
            <FollowedTeamCard
              // Keyed on the follow key: UCLA and the Seahawks are both
              // team 26.
              key={followKey({ league: team.league, teamId: team.id })}
              team={team}
            />
          ))
        )}

        {/* The second door to the sheet, and the one that reads as an
            invitation. */}
        <button
          type="button"
          onClick={() => setIsAdding(true)}
          aria-label="Add teams"
          className="card-surface flex items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-bg-header"
        >
          <span
            aria-hidden="true"
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-bg-elevated"
          >
            <Plus className="h-4 w-4 text-text-primary" />
          </span>
          <span
            aria-hidden="true"
            className="type-team-name-em text-text-primary"
          >
            Add teams
          </span>
          <ChevronRight
            aria-hidden="true"
            className="ml-auto h-3 w-3 shrink-0 text-text-secondary"
          />
        </button>

        <AddTeamsSheet
          open={isAdding}
          onOpenChange={setIsAdding}
          conferences={all.conferences}
          isLoading={all.isLoading}
        />
      </div>
    </>
  );
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center gap-1 px-6 pb-2 pt-10 text-center">
      <p className="type-team-name-em text-text-primary">No teams yet</p>
      <p className="type-meta text-text-secondary">
        Your teams lead the Games screen and your followed tables.
      </p>
    </div>
  );
}

/**
 * One followed team, as its own card. The card navigates; the star unfollows
 * — the same split every browse row in the app uses.
 *
 * The full name, with "NCAAF • SEC" under it (iOS, 2026-09-21). Both lines
 * wrap rather than truncate: "Southern Miss Golden Eagles" is a long name,
 * not a mistake.
 */
function FollowedTeamCard({ team }: { team: Team }) {
  const key = followKey({ league: team.league, teamId: team.id });
  const name = teamFullName(team);

  return (
    <div className="card-surface flex items-center pr-2">
      <Link
        href={teamPath(team)}
        aria-label={teamSpokenLabel(team)}
        className="flex min-w-0 flex-1 items-center gap-3 px-4 py-3 transition-colors hover:bg-bg-header"
      >
        <TeamLogo
          team={team}
          teamName=""
          size="md"
          className="h-10 w-10 shrink-0 object-contain"
        />
        <span aria-hidden="true" className="flex min-w-0 flex-col gap-0.5">
          <span className="line-clamp-2 break-words type-team-name-em text-text-primary">
            {name}
          </span>
          <span className="line-clamp-2 break-words type-meta text-text-secondary">
            {teamSubtitle(team)}
          </span>
        </span>
      </Link>
      <UnfollowStar teamKey={key} label={name} />
    </div>
  );
}

/** The card navigates; the star unfollows, and doesn't navigate. */
function UnfollowStar({
  teamKey,
  label,
}: {
  teamKey: FollowKey;
  label: string;
}) {
  const { toggleFavorite } = useFavoritesContext();
  return (
    <button
      type="button"
      onClick={() => toggleFavorite(teamKey)}
      aria-label={`Unfollow ${label}`}
      aria-pressed={true}
      className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-full text-text-primary transition-colors hover:bg-bg-header"
    >
      <Star aria-hidden="true" className="h-4 w-4 fill-current" />
    </button>
  );
}
