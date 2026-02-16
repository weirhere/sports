"use client";

import { Star } from "lucide-react";
import { cn } from "@/lib/utils";
import { useFavoritesContext } from "@/components/providers/favorites-provider";

interface FavoriteButtonProps {
  teamId: string;
  className?: string;
  size?: "sm" | "md";
}

export function FavoriteButton({ teamId, className, size = "md" }: FavoriteButtonProps) {
  const { isFavorite, toggleFavorite } = useFavoritesContext();
  const active = isFavorite(teamId);

  const iconSize = size === "sm" ? 16 : 20;

  return (
    <button
      type="button"
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        toggleFavorite(teamId);
      }}
      className={cn(
        "inline-flex items-center justify-center rounded-full transition-all",
        size === "sm" ? "h-7 w-7" : "h-9 w-9",
        active
          ? "text-yellow-500 hover:text-yellow-600"
          : "text-muted-foreground hover:text-foreground",
        className
      )}
      aria-label={active ? "Remove from favorites" : "Add to favorites"}
    >
      <Star
        size={iconSize}
        className={cn(
          "transition-transform hover:scale-110 active:scale-95",
          active && "fill-current"
        )}
      />
    </button>
  );
}
