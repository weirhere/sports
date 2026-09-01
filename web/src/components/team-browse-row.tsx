"use client";

// One team in the browse list: logo, location + nickname, follow star —
// the web twin of the iOS `TeamBrowseRow`. The row navigates; the star
// toggles the follow and doesn't.

import Link from "next/link";
import { Star } from "lucide-react";
import { TeamLogo } from "@/components/team-logo";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import type { Team } from "@/lib/types";

export function TeamBrowseRow({ team }: { team: Team }) {
  const { isFavorite, toggleFavorite } = useFavoritesContext();
  const followed = isFavorite(team.id);
  const fullName = [team.school, team.name].filter(Boolean).join(" ");

  return (
    <div className="flex items-center pr-2">
      <Link
        href={`/team/${team.id}`}
        aria-label={fullName}
        className="flex min-w-0 flex-1 items-center gap-3 px-4 py-[5px] transition-colors hover:bg-bg-header"
      >
        {/* Decorative — the row's text carries the name. */}
        <TeamLogo espnId={team.espnId} teamName="" size="sm" />
        <span className="truncate type-row-name-em text-text-primary">
          {team.school}
        </span>
        {team.name && (
          <span className="truncate type-row-name text-text-secondary">
            {team.name}
          </span>
        )}
      </Link>
      <button
        type="button"
        onClick={() => toggleFavorite(team.id)}
        aria-label={followed ? `Unfollow ${team.school}` : `Follow ${team.school}`}
        aria-pressed={followed}
        className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-full text-text-primary transition-colors hover:bg-bg-header"
      >
        <Star
          aria-hidden="true"
          className={followed ? "h-4 w-4 fill-current" : "h-4 w-4"}
        />
      </button>
    </div>
  );
}
