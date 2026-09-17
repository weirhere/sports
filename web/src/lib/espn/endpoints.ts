// Every ESPN URL the app builds, league-parameterized.
//
// Ported alongside the iOS client (StatSideShared/Networking/ESPNClient.swift).
// Nothing here knows what a league *is* beyond its path segments — the rules
// about which leagues take which parameters live in `@/lib/leagues`.

import {
  apiBase,
  espnSeason,
  hasCollegeDivisions,
  leaguePath,
  standingsApiBase,
  type League,
} from "@/lib/leagues";
import { FBS_GROUP_ID } from "@/lib/conferences";

/** ESPN's `dates=` spelling for one day: `20260905`. */
export function espnDay(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}${month}${day}`;
}

/** ESPN's `dates=` spelling for one month: `202609`. */
export function espnMonth(date: Date): string {
  return `${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, "0")}`;
}

/**
 * ESPN's own ceiling on `limit`, and the count that means "this came back
 * truncated".
 *
 * 500 exactly: `limit=501` does not clamp, it collapses the response to
 * ESPN's default 25 events — a silent 93% loss dressed as a 200 (bisected
 * live 2026-09-17). The 900 that used to sit on both window builders was
 * above that ceiling, so every season request had been quietly answering
 * with 25 games.
 */
export const WINDOW_LIMIT = 500;

/** The longest span still asked for a day at a time — see `espnWindow`. */
export const MAX_DAILY_FAN_OUT = 7;

/** Every day a span touches, as `dates=` tokens, in order and deduped. */
export function espnDayTokens(start: Date, end: Date): string[] {
  const tokens: string[] = [];
  const seen = new Set<string>();
  const cursor = new Date(start);
  while (cursor <= end) {
    const token = espnDay(cursor);
    if (!seen.has(token)) {
      seen.add(token);
      tokens.push(token);
    }
    cursor.setDate(cursor.getDate() + 1);
  }
  return tokens;
}

/** Every calendar month a span touches, as `dates=` tokens, in order. */
export function espnMonthTokens(start: Date, end: Date): string[] {
  const tokens: string[] = [];
  const seen = new Set<string>();
  // Walk on the first of the month: stepping from the 31st lands on the
  // 28th of the month after next, and a span ending March 1 loses March.
  const cursor = new Date(start.getFullYear(), start.getMonth(), 1);
  const last = new Date(end.getFullYear(), end.getMonth(), 1);
  while (cursor <= last) {
    const token = espnMonth(cursor);
    if (!seen.has(token)) {
      seen.add(token);
      tokens.push(token);
    }
    cursor.setMonth(cursor.getMonth() + 1);
  }
  return tokens;
}

/**
 * A span's `dates=` tokens, at whichever granularity costs less: one per
 * day up to a week, one per month beyond it.
 *
 * **ESPN withdrew the range form.** `dates=20260915-20260919` now answers
 * `400 {"code":400,"message":"Failed to get events endpoint."}` in all four
 * leagues, past seasons included, and no separator or parameter pairing
 * revives it (probed live 2026-09-17). A day, a month and a year still
 * answer 200, so a span is now several requests rather than one.
 *
 * A month is always the cheaper *request* and never the cheaper *answer* —
 * college football's September is 323 events against a Saturday's 70 — so
 * the Scores window, which is five days and revalidates every 30s, stays
 * daily. A season sweep does not and goes monthly. Either way the caller
 * clips the answer back to the span, so this is a cost decision only.
 */
export function espnWindow(start: Date, end: Date): string[] {
  const days = Math.round((end.getTime() - start.getTime()) / 86_400_000);
  return days > MAX_DAILY_FAN_OUT
    ? espnMonthTokens(start, end)
    : espnDayTokens(start, end);
}

/**
 * The scoreboard.
 *
 * `groups` narrows the slate to one group of ESPN's own hierarchy, and it
 * works in **every** league we cover — college football's FBS/FCS divisions,
 * and a pro league's conferences and divisions alike (probed live
 * 2026-09-09: `groups=4` on the NFL returns the three AFC East games of a
 * week rather than all fifteen). It is sent whenever a caller names one, and
 * only college football gets a *default*, because only it has a division
 * every request has to pick.
 *
 * Two ways to scope it in time, and the difference matters:
 *
 * - `seasonYear` **paired with a `week`** selects that season's week. ESPN
 *   spells the season as `dates=YYYY`, and with a week alongside it that is
 *   exactly what it means.
 * - `dates` takes a day or an inclusive range, for the day axis.
 *
 * What must never happen is a **bare `dates=YYYY` with no week**: alone it
 * is the *calendar* year, so it opens a season's slate with the previous
 * January's bowls and truncates before December (verified live
 * 2026-09-05). `seasonWindowUrl` is how a whole season is asked for.
 */
export function scoreboardUrl(
  league: League,
  params?: {
    week?: number;
    seasonType?: number;
    /** Only honored alongside `week` — see the note above. */
    seasonYear?: number;
    dates?: string;
    groups?: number;
    limit?: number;
  }
): string {
  const url = new URL(`${apiBase(league)}/scoreboard`);
  const groups = params?.groups ?? (hasCollegeDivisions(league) ? FBS_GROUP_ID : undefined);
  if (groups !== undefined) url.searchParams.set("groups", String(groups));
  url.searchParams.set("limit", String(params?.limit ?? 300));
  if (params?.week !== undefined) url.searchParams.set("week", String(params.week));
  if (params?.seasonType !== undefined) {
    url.searchParams.set("seasontype", String(params.seasonType));
  }
  if (params?.dates !== undefined) {
    url.searchParams.set("dates", params.dates);
  } else if (params?.seasonYear !== undefined && params.week !== undefined) {
    url.searchParams.set(
      "dates",
      String(espnSeason(league, params.seasonYear))
    );
  }
  return url.toString();
}

/**
 * One league's slate over a span of days — the Scores screen's only
 * scoreboard request.
 *
 * ESPN reads `dates=` on the **Eastern** clock, which is why the caller
 * fetches a five-day window for a three-day answer: the two-day margin
 * absorbs the ET-to-local offset for every time zone, and only the inner
 * days are recorded as loaded so a half-slate can't pass for a whole one.
 *
 * Takes **one token**, not a span — `espnWindow` turns the span into as
 * many as it needs, since the range form was withdrawn. The caller fans
 * out and merges.
 *
 * A `dates=` request returns **no calendar** and pins `season.year` to the
 * current season, so the day strip's bounds are derived rather than fetched.
 */
export function dayWindowUrl(
  league: League,
  dates: string,
  options?: { groups?: number; limit?: number }
): string {
  return scoreboardUrl(league, {
    dates,
    groups: options?.groups,
    limit: options?.limit ?? WINDOW_LIMIT,
  });
}

/**
 * A whole season's slate, one token at a time.
 *
 * A season is asked for month by month — the range form that used to state
 * it whole is gone, and the month is the coarsest token left. ESPN still
 * truncates at `limit` silently rather than paging, so a month that comes
 * back at `WINDOW_LIMIT` is re-asked as its own days by the caller.
 */
export function seasonWindowUrl(
  league: League,
  dates: string,
  options?: { groups?: number; limit?: number }
): string {
  return scoreboardUrl(league, {
    dates,
    groups: options?.groups,
    limit: options?.limit ?? WINDOW_LIMIT,
  });
}

export function gameSummaryUrl(league: League, gameId: string): string {
  const url = new URL(`${apiBase(league)}/summary`);
  url.searchParams.set("event", gameId);
  return url.toString();
}

/** College football only — `/rankings` is a 404 for the other three. */
export function rankingsUrl(league: League): string {
  return `${apiBase(league)}/rankings`;
}

/**
 * Standings. `season` scopes records AND membership, so realignment years
 * read correctly.
 *
 * `level` walks ESPN's group tree: the shipped response stops at the
 * conferences, and `level=3` is what reaches a pro league's divisions.
 */
export function standingsUrl(
  league: League,
  params?: { year?: number; group?: number; level?: number }
): string {
  const url = new URL(`${standingsApiBase(league)}/standings`);
  if (hasCollegeDivisions(league)) {
    url.searchParams.set("group", String(params?.group ?? FBS_GROUP_ID));
  }
  if (params?.year !== undefined) {
    url.searchParams.set("season", String(espnSeason(league, params.year)));
  }
  if (params?.level !== undefined) {
    url.searchParams.set("level", String(params.level));
  }
  return url.toString();
}

/**
 * A bare /schedule request inherits ESPN's "current" season type, which is
 * the empty preseason from February until kickoff — so ask for the season
 * explicitly. Preseason (1), regular season (2) and postseason (3) are
 * separate requests.
 */
export function teamScheduleUrl(
  league: League,
  teamId: string,
  params: { year: number; seasonType: number }
): string {
  const url = new URL(`${apiBase(league)}/teams/${teamId}/schedule`);
  url.searchParams.set("season", String(espnSeason(league, params.year)));
  url.searchParams.set("seasontype", String(params.seasonType));
  return url.toString();
}

/**
 * ESPN's **core** API — the one surface with a season axis for rankings.
 *
 * The site API's `/rankings` is latest-only: it ignores `season`, `week`,
 * `year` and `dates` alike and always answers with the newest poll it has
 * (probed live 2026-09-05), so it can speak for the season in progress and
 * nothing else.
 */
const CORE_BASE = "https://sports.core.api.espn.com/v2/sports";

function coreLeagueBase(league: League): string {
  return `${CORE_BASE}/${leaguePath(league)}/seasons`;
}

/**
 * One published ranking table. `rankingId` is the poll: 1 AP, 2 Coaches,
 * 21 CFP.
 *
 * The AP and Coaches polls end in the postseason (`types/3/weeks/1`,
 * headlined "Final Rankings"); the CFP's last table is selection day's — the
 * final week of the *regular* season, since a postseason CFP table is a 404.
 */
export function coreRankingUrl(
  league: League,
  params: { year: number; seasonType: number; week: number; rankingId: number }
): string {
  return (
    `${coreLeagueBase(league)}/${params.year}` +
    `/types/${params.seasonType}/weeks/${params.week}/rankings/${params.rankingId}`
  );
}

/** How many weeks a season type has — the CFP's closing week is 15 or 16
 *  depending on the year, so it is read off rather than assumed. */
export function coreWeeksUrl(
  league: League,
  params: { year: number; seasonType: number }
): string {
  return (
    `${coreLeagueBase(league)}/${params.year}` +
    `/types/${params.seasonType}/weeks?limit=1`
  );
}

/** The league's full team directory — one request, no conference data. */
export function teamsUrl(league: League, limit = 1000): string {
  const url = new URL(`${apiBase(league)}/teams`);
  url.searchParams.set("limit", String(limit));
  return url.toString();
}

/**
 * One team's roster.
 *
 * **No season parameter, deliberately.** `?season=2019` answers 200, echoes
 * the season back and carries zero athletes (probed live 2026-09-10 on
 * college football, the NFL and the NBA) — the endpoint has no season axis,
 * which is also why the Roster tab shows no season chip.
 */
export function teamRosterUrl(league: League, teamId: string): string {
  return `${apiBase(league)}/teams/${teamId}/roster`;
}
