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

type FollowPillProps = {
  league: League;
  /** Spoken name for the accessible label. */
  name: string;
} & (
  | {
      kind: "team" | "conference";
      /** Raw ESPN id — team id, or the conference group id as a string. */
      id: string;
    }
  // A poll is followed by league alone: the set is keyed that way so a
  // league that grows a poll needs no migration, and there is no id to
  // carry (iOS, 2026-09-05).
  | { kind: "poll"; id?: undefined }
);

export function FollowPill({ league, id, kind, name }: FollowPillProps) {
  const {
    isFavorite,
    toggleFavorite,
    isFavoriteConference,
    toggleFavoriteConference,
    isFavoritePoll,
    toggleFavoritePoll,
  } = useFavoritesContext();

  // Branched rather than one shared `key`: a team key and a conference
  // token are distinct branded types, so the compiler keeps each one with
  // the store it belongs to.
  const following =
    kind === "team"
      ? isFavorite(followKey({ league, teamId: id }))
      : kind === "conference"
        ? isFavoriteConference(conferenceToken({ league, id: Number(id) }))
        : isFavoritePoll(league);
  const toggle = () => {
    if (kind === "team") toggleFavorite(followKey({ league, teamId: id }));
    else if (kind === "conference") {
      toggleFavoriteConference(conferenceToken({ league, id: Number(id) }));
    } else toggleFavoritePoll(league);
  };

  return (
    <button
      type="button"
      onClick={toggle}
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
