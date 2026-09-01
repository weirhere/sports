import { ScoresView } from "./scores-view";
import { scoreboard } from "@/lib/espn";
import type { Scoreboard } from "@/lib/types";

// The landing page reads the live slate on every request — never frozen at
// build time. The provider's 30s revalidate window is the request throttle.
export const dynamic = "force-dynamic";

const EMPTY_BOARD: Scoreboard = { weeks: [], games: [] };

export default async function ScoresPage() {
  // A dead ESPN response degrades to the empty state instead of a 500 —
  // the client can still walk weeks/seasons, which retries via /api.
  const board = await scoreboard({}).catch(() => EMPTY_BOARD);

  return (
    <div>
      <ScoresView
        initialGames={board.games}
        initialWeeks={board.weeks}
        initialCurrentWeekNumber={board.currentWeekNumber}
        initialSeasonType={board.seasonType}
        initialSeasonYear={board.seasonYear}
      />
    </div>
  );
}
