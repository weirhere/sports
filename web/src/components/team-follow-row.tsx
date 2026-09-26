"use client";

// One team in the Add teams sheet — the web twin of iOS `TeamFollowRow`.
//
// The **whole row** toggles the follow rather than navigating: the sheet's
// question is "which teams are mine?", and a page visit isn't part of
// answering it. The Teams tab behind it is where a followed team's page is
// one tap away.
//
// **One name, in one string** — "Ohio State Buckeyes", "Dallas Cowboys"
// (iOS, 2026-09-21). The location set against the nickname in two weights
// read as two facts about a team rather than its name. It wraps to a second
// line rather than truncating: a browser column can be narrower than a
// phone's, and an ellipsis mid-name is the worse answer.

import { Star } from "lucide-react";
import { TeamLogo } from "@/components/team-logo";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { followKey } from "@/lib/refs";
import { displayName, shortName, type League } from "@/lib/leagues";
import { teamFullName } from "@/lib/team-name";
import type { Team } from "@/lib/types";
import { cn } from "@/lib/utils";

export function TeamFollowRow({
  team,
  /**
   * Set where a result set spans leagues — that tag disambiguates two teams
   * in front of you, which is a different job from the headings that came
   * out of the sheet.
   */
  leagueTag,
}: {
  team: Team;
  leagueTag?: League;
}) {
  const { isFavorite, toggleFavorite } = useFavoritesContext();
  // League-qualified, never `team.id`: id 5 is UAB and the Browns.
  const key = followKey({ league: team.league, teamId: team.id });
  const followed = isFavorite(key);
  const name = teamFullName(team);
  // The phrase, not the initialism a screen reader would spell out.
  const spoken = leagueTag ? `${name}, ${displayName(leagueTag)}` : name;

  return (
    <button
      type="button"
      onClick={() => toggleFavorite(key)}
      aria-pressed={followed}
      aria-label={followed ? `Unfollow ${spoken}` : `Follow ${spoken}`}
      className="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-bg-header"
    >
      <TeamLogo
        team={team}
        teamName=""
        size="md"
        className="h-8 w-8 shrink-0 object-contain"
      />
      {/* The weight follows the follow, as the iOS row's does. */}
      <span
        aria-hidden="true"
        className={cn(
          "line-clamp-2 min-w-0 flex-1 break-words text-text-primary",
          followed ? "type-team-name-em" : "type-team-name"
        )}
      >
        {name}
      </span>
      {leagueTag && (
        <span
          aria-hidden="true"
          className="shrink-0 type-meta tracking-[0.03em] text-text-secondary"
        >
          {shortName(leagueTag)}
        </span>
      )}
      <Star
        aria-hidden="true"
        className={cn(
          "h-5 w-5 shrink-0 text-text-primary",
          followed && "fill-current"
        )}
      />
    </button>
  );
}
