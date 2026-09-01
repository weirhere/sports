"use client";

import { cn } from "@/lib/utils";
import { useFavoritesContext } from "@/components/providers/favorites-provider";

interface FavoriteButtonProps {
  teamId: string;
  type?: "team" | "conference";
  className?: string;
  size?: "sm" | "md";
}

export function FavoriteButton({
  teamId,
  type = "team",
  className,
  size = "md",
}: FavoriteButtonProps) {
  const {
    isFavorite,
    toggleFavorite,
    isFavoriteConference,
    toggleFavoriteConference,
  } = useFavoritesContext();
  const active =
    type === "conference"
      ? isFavoriteConference(teamId)
      : isFavorite(teamId);
  const toggle =
    type === "conference" ? toggleFavoriteConference : toggleFavorite;

  return (
    <button
      type="button"
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        toggle(teamId);
      }}
      className={cn(
        "shrink-0 rounded-full border text-xs font-medium transition-colors",
        size === "sm" ? "px-3 py-1" : "px-4 py-1.5",
        active
          ? "border-border bg-transparent text-muted-foreground"
          : "border-border bg-transparent text-muted-foreground hover:border-foreground/30 hover:text-foreground",
        className
      )}
      aria-label={active ? "Unfollow" : "Follow"}
    >
      {active ? "Following" : "Follow"}
    </button>
  );
}
