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
import { TeamLogo } from "@/components/team-logo";
import { Skeleton } from "@/components/ui/skeleton";
import { useTeamDirectory } from "@/lib/hooks/use-team-directory";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { conferenceName, divisionForTeamId } from "@/lib/conferences";
import { LEAGUES, shortName } from "@/lib/leagues";
import { followedLeagues, followKey, type FollowKey } from "@/lib/refs";
import { teamPath } from "@/lib/routes";
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
    <div className="flex flex-col gap-2">
      {/* The nav bar shows the wordmark on every route now, so the tab bar
          and the active nav link are what name this page for sighted users.
          Assistive tech reads neither as a heading. */}
      <h1 className="sr-only">Teams</h1>
      {loading ? (
        [0, 1, 2].map((row) => (
          <Skeleton key={row} className="h-[72px] w-full rounded-[10px]" />
        ))
      ) : teams.length === 0 ? (
        <EmptyState />
      ) : (
        teams.map((team) => (
          <FollowedTeamCard
            // Keyed on the follow key: UCLA and the Seahawks are both team 26.
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
        <span aria-hidden="true" className="type-team-name-em text-text-primary">
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
 */
function FollowedTeamCard({ team }: { team: Team }) {
  const key = followKey({ league: team.league, teamId: team.id });
  const group = groupName(team);
  const subtitle = [team.name, group].filter(Boolean).join(" · ");

  return (
    <div className="card-surface flex items-center pr-2">
      <Link
        href={teamPath(team)}
        aria-label={[team.school, group].filter(Boolean).join(", ")}
        className="flex min-w-0 flex-1 items-center gap-3 px-4 py-3 transition-colors hover:bg-bg-header"
      >
        <TeamLogo
          team={team}
          teamName=""
          size="md"
          className="h-10 w-10 shrink-0 object-contain"
        />
        <span aria-hidden="true" className="min-w-0">
          <span className="block truncate type-team-name-em text-text-primary">
            {team.school}
          </span>
          {subtitle && (
            <span className="block truncate type-meta text-text-secondary">
              {subtitle}
            </span>
          )}
        </span>
      </Link>
      <UnfollowStar teamKey={key} label={team.school} />
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

/**
 * The group the team plays in, with the league in front of it (iOS,
 * 2026-09-09: "Cleveland Cavaliers are NBA Eastern. Tampa Bay Lightning are
 * NHL Eastern").
 *
 * The league is what makes the group a name rather than a word: the directory
 * files basketball and hockey teams under their *conference*, and both
 * leagues call theirs Eastern and Western — so a card of followed teams was
 * two identical subtitles for teams in different sports.
 *
 * For the NFL the group is the **division**: the directory files those teams
 * under their conference too, so the team's own id would only ever say AFC or
 * NFC.
 */
function groupName(team: Team): string | undefined {
  const raw = rawGroupName(team);
  if (!raw) return undefined;
  const league = shortName(team.league);
  return raw.toLowerCase().includes(league.toLowerCase())
    ? raw
    : `${league} ${raw}`;
}

function rawGroupName(team: Team): string | undefined {
  if (team.league === "nfl") {
    const division = divisionForTeamId(team.id, "nfl");
    if (division !== undefined) return conferenceName(division, "nfl");
  }
  const id = Number(team.conferenceId);
  if (!Number.isInteger(id)) return undefined;
  const name = conferenceName(id, team.league);
  return name === "Other" ? undefined : name;
}
