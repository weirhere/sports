"use client";

// The hero's follow control — iOS `FollowPill`/`ConferenceFollowPill`: star
// glyph + Follow/Following, ink-filled while following.
//
// Wired to the favorites store with **league-qualified keys**, never raw
// ESPN ids: id 5 is UAB and the Browns, and group 8 is the SEC and the AFC,
// so a bare id would follow both at once.

import { Star } from "lucide-react";
import { cn } from "@/lib/utils";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import type { League } from "@/lib/leagues";
import { conferenceToken, followKey } from "@/lib/refs";

interface FollowPillProps {
  league: League;
  /** Raw ESPN id — team id, or the conference group id as a string. */
  id: string;
  kind: "team" | "conference";
  /** Spoken name for the accessible label. */
  name: string;
}

export function FollowPill({ league, id, kind, name }: FollowPillProps) {
  const {
    isFavorite,
    toggleFavorite,
    isFavoriteConference,
    toggleFavoriteConference,
  } = useFavoritesContext();

  const key =
    kind === "team"
      ? followKey({ league, teamId: id })
      : conferenceToken({ league, id: Number(id) });
  const following =
    kind === "team" ? isFavorite(key) : isFavoriteConference(key);
  const toggle =
    kind === "team" ? toggleFavorite : toggleFavoriteConference;

  return (
    <button
      type="button"
      onClick={() => toggle(key)}
      aria-pressed={following}
      aria-label={following ? `Unfollow ${name}` : `Follow ${name}`}
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full px-4 py-1.5 type-chip-em transition-colors",
        following
          ? "bg-text-primary text-bg-primary"
          : "bg-bg-elevated text-text-primary hover:bg-divider"
      )}
    >
      <Star
        aria-hidden="true"
        className={cn("h-3.5 w-3.5", following && "fill-current")}
      />
      {following ? "Following" : "Follow"}
    </button>
  );
}
