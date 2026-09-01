"use client";

import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { useFavoritesContext } from "@/components/providers/favorites-provider";

interface ConferenceRowProps {
  id: string;
  name: string;
  shortName: string;
  showFollowButton?: boolean;
  onFollow?: () => void;
}

/**
 * A single conference row meant to live inside a card container.
 * No border/rounded — the parent card provides that.
 */
export function ConferenceRow({
  id,
  name,
  shortName,
  showFollowButton = false,
  onFollow,
}: ConferenceRowProps) {
  const { isFavoriteConference, toggleFavoriteConference } =
    useFavoritesContext();
  const favorited = isFavoriteConference(id);

  return (
    <Link
      href={`/conferences/${id}`}
      className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-accent/30"
    >
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">{shortName}</p>
        <p className="text-xs text-muted-foreground">{name}</p>
      </div>
      {showFollowButton && !favorited ? (
        <button
          type="button"
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            toggleFavoriteConference(id);
            onFollow?.();
          }}
          className="shrink-0 rounded-full border border-border bg-transparent px-3 py-1 text-xs font-medium text-muted-foreground transition-colors hover:border-foreground/30 hover:text-foreground"
          aria-label="Follow conference"
        >
          Follow
        </button>
      ) : !showFollowButton ? (
        <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground" />
      ) : null}
    </Link>
  );
}
