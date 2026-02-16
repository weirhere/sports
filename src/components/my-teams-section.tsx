"use client";

import type { Game } from "@/lib/types";
import { GameCard } from "@/components/game-card";
import { useFavoritesContext } from "@/components/providers/favorites-provider";

interface MyTeamsSectionProps {
  games: Game[];
}

export function MyTeamsSection({ games }: MyTeamsSectionProps) {
  const { favorites, isLoaded } = useFavoritesContext();

  if (!isLoaded || favorites.length === 0) return null;

  const myGames = games.filter(
    (g) =>
      favorites.includes(g.homeTeam.team.id) ||
      favorites.includes(g.awayTeam.team.id)
  );

  if (myGames.length === 0) return null;

  return (
    <div className="mb-6">
      <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
        My Teams
      </h2>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {myGames.map((game) => (
          <GameCard
            key={game.id}
            game={game}
            className="border-primary/20 bg-primary/[0.02]"
          />
        ))}
      </div>
    </div>
  );
}
