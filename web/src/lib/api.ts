import type { GameDetail, Scoreboard } from "./types";
import type { HeadToHead } from "./head-to-head";
import type { TrophyCase } from "./trophies";
import type { PlayerGameLog } from "./player-stats";
import type { League } from "./leagues";
import { dayId } from "./day";

const BASE = "/api";

/**
 * A failed call to our own API, carrying the upstream status where the
 * route knew one.
 *
 * The route maps every ESPN failure to a flat 502, which told the browser
 * only that something went wrong — and "something went wrong" is what the
 * Scores screen had to print. `upstreamStatus` is ESPN's own answer, and
 * it is the difference between "they moved the endpoint" and "ESPN is
 * down".
 */
export class ApiError extends Error {
  readonly status: number;
  readonly upstreamStatus?: number;

  constructor(status: number, upstreamStatus?: number) {
    super(
      upstreamStatus === undefined
        ? `API error: ${status}`
        : `API error: ${status} (upstream ${upstreamStatus})`
    );
    this.name = "ApiError";
    this.status = status;
    this.upstreamStatus = upstreamStatus;
  }
}

async function fetchJson<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) {
    let upstreamStatus: number | undefined;
    try {
      const body: unknown = await res.json();
      const reported = (body as { upstreamStatus?: unknown })?.upstreamStatus;
      if (typeof reported === "number") upstreamStatus = reported;
    } catch {
      // No JSON body, or an empty one. The status alone will have to do.
    }
    throw new ApiError(res.status, upstreamStatus);
  }
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

/**
 * One matchup's series — the previous meetings and the tally they add up to.
 *
 * Its own request, not part of the page's, because it is a season-by-season
 * walk: ESPN has no head-to-head resource, so the bill is two requests per
 * season and it is only worth paying when the tab is actually opened.
 */
export async function getHeadToHead(
  league: League,
  gameId: string
): Promise<HeadToHead> {
  return fetchJson(`${BASE}/game/${gameId}/head-to-head?league=${league}`);
}

/**
 * One team's trophy case — every season back to the floor, derived from the
 * games it played. Requested on the tab's first open for the series' reason,
 * doubled: a dozen seasons is a dozen pairs of requests.
 */
export async function getTeamTrophies(
  league: League,
  teamId: string
): Promise<TrophyCase> {
  return fetchJson(`${BASE}/team/${teamId}/trophies?league=${league}`);
}

/**
 * One season of a player's games. `season` is ESPN's own year (the ending
 * year for basketball and hockey); undefined asks for ESPN's current one.
 * Requested when the Games tab first opens — most visits never do.
 */
export async function getPlayerGameLog(
  league: League,
  athleteId: string,
  season?: number
): Promise<PlayerGameLog> {
  const params = new URLSearchParams({ league });
  if (season !== undefined) params.set("season", String(season));
  return fetchJson(`${BASE}/player/${athleteId}/gamelog?${params}`);
}
