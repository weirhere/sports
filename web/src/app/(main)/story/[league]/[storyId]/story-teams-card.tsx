"use client";

// "In this story" (iOS `StoryTeamsCard`, docs/news.md N6): a row per team
// the story is tagged with — the row opens the team, the capsule follows it.
// FotMob closes every article this way, so reading turns into following.
// Teams only: StatSide's follows are team-shaped by decision.

import Link from "next/link";
import { FollowCapsuleButton } from "@/components/follow-capsule";
import { CardHeader } from "@/components/card-header";
import { TeamLogo } from "@/components/team-logo";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { followKey } from "@/lib/refs";
import { teamPath } from "@/lib/routes";
import { teamFullName, teamSpokenLabel } from "@/lib/team-name";
import type { Team } from "@/lib/types";
import { cn } from "@/lib/utils";

export function StoryTeamsCard({ teams }: { teams: Team[] }) {
  const { isFavorite, toggleFavorite } = useFavoritesContext();
  return (
    <section className="card-surface pb-1">
      <CardHeader title="In this story" />
      {teams.map((team, index) => {
        const key = followKey({ league: team.league, teamId: team.id });
        const followed = isFavorite(key);
        const name = teamFullName(team);
        return (
          <div key={key}>
            {index > 0 && <div className="ml-4 border-t border-divider" />}
            <div className="flex items-center pr-4">
              <Link
                href={teamPath(team)}
                aria-label={teamSpokenLabel(team)}
                className="flex min-w-0 flex-1 items-center gap-3 px-4 py-3 transition-colors hover:bg-bg-header"
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
                    "line-clamp-2 min-w-0 break-words text-text-primary",
                    followed ? "type-team-name-em" : "type-team-name"
                  )}
                >
                  {name}
                </span>
              </Link>
              <FollowCapsuleButton
                followed={followed}
                name={name}
                onToggle={() => toggleFavorite(key)}
              />
            </div>
          </div>
        );
      })}
    </section>
  );
}
