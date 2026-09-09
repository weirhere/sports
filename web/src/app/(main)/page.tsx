// The landing page: today's slate, every league, read live on every request
// — never frozen at build time. The provider's 30s revalidate window is the
// request throttle.
//
// The server renders one day so the first paint carries real games; the
// client hook takes over from there, and its own five-day window subsumes
// this one. Each league fails independently: a dead NHL response costs the
// NHL's section, not the page.

import { ScoresView } from "./scores-view";
import { scoreboardForDays } from "@/lib/espn";
import { addDays, clampDay, dayId, startOfDay } from "@/lib/day";
import { LEAGUES, seasonYearContaining, unionSeasonSpan } from "@/lib/leagues";
import type { Game } from "@/lib/types";
import type { League } from "@/lib/leagues";

export const dynamic = "force-dynamic";

/** The window radius the client hook uses, so the two agree on a day. */
const WINDOW_RADIUS = 2;

export default async function ScoresPage() {
  // Today, unless today is outside every league's season — the deep
  // offseason opens on the season's nominal start, and the client's probe
  // walks forward from there to the first day anyone plays.
  const today = startOfDay(new Date());
  const span = unionSeasonSpan(seasonYearContaining(today));
  const day = clampDay(today, span.start, span.end);

  const results = await Promise.all(
    LEAGUES.map(async (league) => {
      try {
        const board = await scoreboardForDays(
          league,
          addDays(day, -WINDOW_RADIUS),
          addDays(day, WINDOW_RADIUS)
        );
        return { league, games: board.games };
      } catch {
        // A dead response costs this league's section, not the page. The
        // client refetches on mount for anything that missed.
        return undefined;
      }
    })
  );

  const loaded = results.filter(
    (result): result is { league: League; games: Game[] } => result !== undefined
  );
  const id = dayId(day);
  const games = loaded
    .flatMap((result) => result.games)
    // The seed carries only the rendered day; the window's outer days are a
    // partial answer for most time zones and belong to the client's own
    // bookkeeping.
    .filter((game) => {
      const time = Date.parse(game.scheduledAt);
      return Number.isFinite(time) && dayId(new Date(time)) === id;
    });

  return (
    <div>
      <ScoresView
        seed={{
          dayId: id,
          games,
          leagues: loaded.map((result) => result.league),
        }}
      />
    </div>
  );
}
