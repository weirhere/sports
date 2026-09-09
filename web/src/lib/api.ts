import type { GameDetail, Scoreboard } from "./types";
import type { League } from "./leagues";
import { dayId } from "./day";

const BASE = "/api";

async function fetchJson<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

/**
 * Fetch the scoreboard. No `slot` means ESPN's current week.
 *
 * `league` is required, not defaulted: it selects the ESPN base URL, and a
 * missing one is a 400 rather than a quiet fall back to college football.
 */
export async function getScoreboard(
  league: League,
  slot?: { value: number; seasonType: number },
  year?: number
): Promise<Scoreboard> {
  const params = new URLSearchParams({ league });
  if (slot !== undefined) {
    params.set("week", String(slot.value));
    params.set("seasontype", String(slot.seasonType));
  }
  // Only meaningful alongside a week; the route drops it otherwise.
  if (year !== undefined) params.set("year", String(year));
  return fetchJson(`${BASE}/scoreboard?${params}`);
}

/**
 * One league's slate over a span of local days — the Scores screen's only
 * scoreboard request.
 *
 * The caller asks for five days to answer for three: ESPN reads `dates=` on
 * the Eastern clock, and the two-day margin absorbs the ET-to-local offset
 * for every time zone.
 */
export async function getScoreboardDays(
  league: League,
  start: Date,
  end: Date
): Promise<Scoreboard> {
  const params = new URLSearchParams({
    league,
    start: dayId(start),
    end: dayId(end),
  });
  return fetchJson(`${BASE}/scoreboard?${params}`);
}

/**
 * One game's detail. Event ids are per-league — a summary fetched from the
 * wrong league's base URL 404s — so the league rides the request.
 */
export async function getGameDetail(
  league: League,
  gameId: string
): Promise<GameDetail> {
  return fetchJson(`${BASE}/game/${gameId}?league=${league}`);
}
