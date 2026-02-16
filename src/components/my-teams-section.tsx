"use client";

import type { Game, GameStatus } from "@/lib/types";
import { GameRow } from "@/components/game-row";
import { useFavoritesContext } from "@/components/providers/favorites-provider";

/** 0 = live/active, 1 = upcoming/scheduled, 2 = completed */
function statusGroup(status: GameStatus): number {
  switch (status) {
    case "in_progress":
    case "halftime":
    case "end_period":
      return 0;
    case "scheduled":
    case "delayed":
    case "postponed":
      return 1;
    case "complete":
    case "cancelled":
    default:
      return 2;
  }
}

interface MyTeamsSectionProps {
  games: Game[];
}

export function MyTeamsSection({ games }: MyTeamsSectionProps) {
  const { favorites, favoriteConferences, isLoaded } = useFavoritesContext();

  if (!isLoaded || (favorites.length === 0 && favoriteConferences.length === 0)) return null;

  // Sort order:
  // 1. Status group: active → upcoming → complete
  // 2. Source tier: team favorites before conference-only
  // 3. Favorites priority order within each tier
  const seen = new Set<string>();

  type Indexed = { game: Game; group: number; tier: number; favKey: number };
  const indexed: Indexed[] = [];

  // Tag team-followed games (tier 0).
  for (const g of games) {
    const homeIdx = favorites.indexOf(g.homeTeam.team.id);
    const awayIdx = favorites.indexOf(g.awayTeam.team.id);
    if (homeIdx === -1 && awayIdx === -1) continue;
    const bestIdx =
      homeIdx === -1 ? awayIdx : awayIdx === -1 ? homeIdx : Math.min(homeIdx, awayIdx);
    seen.add(g.id);
    indexed.push({ game: g, group: statusGroup(g.status), tier: 0, favKey: bestIdx });
  }

  // Tag conference-only games (tier 1), skipping duplicates.
  for (const g of games) {
    if (seen.has(g.id)) continue;
    const homeIdx = favoriteConferences.indexOf(g.homeTeam.team.conferenceId);
    const awayIdx = favoriteConferences.indexOf(g.awayTeam.team.conferenceId);
    if (homeIdx === -1 && awayIdx === -1) continue;
    const bestIdx =
      homeIdx === -1 ? awayIdx : awayIdx === -1 ? homeIdx : Math.min(homeIdx, awayIdx);
    indexed.push({ game: g, group: statusGroup(g.status), tier: 1, favKey: bestIdx });
  }

  indexed.sort((a, b) => {
    // 1. Status group: active → upcoming → complete
    if (a.group !== b.group) return a.group - b.group;
    // 2. Within upcoming games, sort by kickoff time (soonest first)
    if (a.group === 1) {
      const timeA = new Date(a.game.scheduledAt).getTime();
      const timeB = new Date(b.game.scheduledAt).getTime();
      if (timeA !== timeB) return timeA - timeB;
    }
    // 3. Source tier: team favorites before conference-only
    if (a.tier !== b.tier) return a.tier - b.tier;
    // 4. Favorites priority order within each tier
    return a.favKey - b.favKey;
  });

  const myGames = indexed.map((x) => x.game);

  if (myGames.length === 0) return null;

  return (
    <div className="mb-6">
      <div className="overflow-hidden rounded-xl border bg-card shadow-card">
        <div className="px-4 py-3 bg-muted/50">
          <span className="text-sm font-semibold text-foreground">
            Following
          </span>
        </div>
        <div className="border-t">
          {myGames.map((game, i) => (
            <div key={game.id}>
              {i > 0 && <div className="mx-4 border-t" />}
              <GameRow game={game} />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
