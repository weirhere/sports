import { ESPN_API_BASE } from "@/lib/constants";
import { FBS_GROUP_ID } from "@/lib/conferences";

// Conference membership lives on the standings API (apis/v2, not site/v2);
// the /teams endpoint carries no conference data.
export const ESPN_STANDINGS_API_BASE =
  "https://site.api.espn.com/apis/v2/sports/football/college-football";

/**
 * Scoreboard. Pass nothing to get ESPN's current week. `year` is ESPN's
 * `dates=` param and selects a season — always pair it with an explicit
 * week for the FBS slate; a bare year request dumps the entire season's
 * events (which is exactly what `conferenceGamesUrl` wants).
 */
export function scoreboardUrl(params?: {
  week?: number;
  seasonType?: number;
  year?: number;
  groups?: number;
  limit?: number;
}): string {
  const url = new URL(`${ESPN_API_BASE}/scoreboard`);
  url.searchParams.set("groups", String(params?.groups ?? FBS_GROUP_ID));
  url.searchParams.set("limit", String(params?.limit ?? 300));
  if (params?.week !== undefined) {
    url.searchParams.set("week", String(params.week));
  }
  if (params?.seasonType !== undefined) {
    url.searchParams.set("seasontype", String(params.seasonType));
  }
  if (params?.year !== undefined) {
    url.searchParams.set("dates", String(params.year));
  }
  return url.toString();
}

export function gameSummaryUrl(gameId: string): string {
  const url = new URL(`${ESPN_API_BASE}/summary`);
  url.searchParams.set("event", gameId);
  return url.toString();
}

export function rankingsUrl(): string {
  return `${ESPN_API_BASE}/rankings`;
}

/** `season` scopes records AND membership (realignment years read correctly). */
export function standingsUrl(params?: {
  year?: number;
  group?: number;
}): string {
  const url = new URL(`${ESPN_STANDINGS_API_BASE}/standings`);
  url.searchParams.set("group", String(params?.group ?? FBS_GROUP_ID));
  if (params?.year !== undefined) {
    url.searchParams.set("season", String(params.year));
  }
  return url.toString();
}

/**
 * A bare /schedule request inherits ESPN's "current" season type, which is
 * the empty preseason from February until kickoff — so ask for the season
 * explicitly. Regular season (2) and postseason (3) are separate requests.
 */
export function teamScheduleUrl(
  teamId: string,
  params: { year: number; seasonType: number }
): string {
  const url = new URL(`${ESPN_API_BASE}/teams/${teamId}/schedule`);
  url.searchParams.set("season", String(params.year));
  url.searchParams.set("seasontype", String(params.seasonType));
  return url.toString();
}
