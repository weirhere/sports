"use client";

// One team in the Add teams sheet — the web twin of iOS `TeamFollowRow`.
//
// The **whole row** toggles the follow rather than navigating: the sheet's
// question is "which teams are mine?", and a page visit isn't part of
// answering it. The Teams tab behind it is where a followed team's page is
// one tap away.

import { Star } from "lucide-react";
import { TeamLogo } from "@/components/team-logo";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { followKey } from "@/lib/refs";
import { shortName, type League } from "@/lib/leagues";
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
  const name = [team.school, team.name].filter(Boolean).join(" ");

  return (
    <button
      type="button"
      onClick={() => toggleFavorite(key)}
      aria-pressed={followed}
      aria-label={followed ? `Unfollow ${name}` : `Follow ${name}`}
      className="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-bg-header"
    >
      <TeamLogo
        team={team}
        teamName=""
        size="md"
        className="h-8 w-8 shrink-0 object-contain"
      />
      <span aria-hidden="true" className="min-w-0 flex-1">
        <span className="block truncate type-team-name-em text-text-primary">
          {team.school}
        </span>
        <span className="block truncate type-meta text-text-secondary">
          {[team.name, leagueTag ? shortName(leagueTag) : undefined]
            .filter(Boolean)
            .join(" · ")}
        </span>
      </span>
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
