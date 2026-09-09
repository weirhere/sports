import { ScoresView } from "./scores-view";
import { scoreboard } from "@/lib/espn";
import type { Scoreboard } from "@/lib/types";
import type { League } from "@/lib/leagues";

// The landing page reads the live slate on every request — never frozen at
// build time. The provider's 30s revalidate window is the request throttle.
export const dynamic = "force-dynamic";

// Still college football alone: the day strip and the cross-league slate
// are W2's, and until then this page is one league's week. Stated rather
// than assumed — the provider takes a league now, so there is no default to
// be wrong about.
const LEAGUE: League = "cfb";

const EMPTY_BOARD: Scoreboard = { league: LEAGUE, weeks: [], games: [] };

export default async function ScoresPage() {
  // A dead ESPN response degrades to the empty state instead of a 500 —
  // the client can still walk weeks/seasons, which retries via /api.
  const board = await scoreboard(LEAGUE).catch(() => EMPTY_BOARD);

  return (
    <div>
      <ScoresView
        league={LEAGUE}
        initialGames={board.games}
        initialWeeks={board.weeks}
        initialCurrentWeekNumber={board.currentWeekNumber}
        initialSeasonType={board.seasonType}
        initialSeasonYear={board.seasonYear}
      />
    </div>
  );
}
