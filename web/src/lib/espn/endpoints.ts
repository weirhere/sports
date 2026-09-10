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

/** ESPN's `dates=` spelling for an inclusive range. */
export function espnDayRange(start: Date, end: Date): string {
  return `${espnDay(start)}-${espnDay(end)}`;
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
 * A `dates=` request returns **no calendar** and pins `season.year` to the
 * current season, so the day strip's bounds are derived rather than fetched.
 */
export function dayWindowUrl(
  league: League,
  start: Date,
  end: Date,
  options?: { groups?: number; limit?: number }
): string {
  return scoreboardUrl(league, {
    dates: espnDayRange(start, end),
    groups: options?.groups,
    limit: options?.limit ?? 900,
  });
}

/**
 * A whole season's slate, as a date window.
 *
 * Split into two requests by the caller where the span is wide enough to
 * approach ESPN's 900-event ceiling — it truncates silently rather than
 * paging, so a season is asked for in halves rather than trusted whole.
 */
export function seasonWindowUrl(
  league: League,
  start: Date,
  end: Date,
  options?: { groups?: number; limit?: number }
): string {
  return scoreboardUrl(league, {
    dates: espnDayRange(start, end),
    groups: options?.groups,
    limit: options?.limit ?? 900,
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
