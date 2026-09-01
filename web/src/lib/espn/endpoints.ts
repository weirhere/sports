import { ESPN_API_BASE, CURRENT_SEASON_YEAR } from "@/lib/constants";

export function scoreboardUrl(params?: {
  week?: number;
  year?: number;
  groups?: number; // 80 = FBS, 81 = FCS
  limit?: number;
}): string {
  const url = new URL(`${ESPN_API_BASE}/scoreboard`);
  const year = params?.year ?? CURRENT_SEASON_YEAR;
  url.searchParams.set("lang", "en");
  url.searchParams.set("region", "us");
  url.searchParams.set("calendartype", "blacklist");
  url.searchParams.set("limit", String(params?.limit ?? 100));
  url.searchParams.set("dates", String(year));
  url.searchParams.set("seasontype", "2"); // regular season
  if (params?.week !== undefined) {
    url.searchParams.set("week", String(params.week));
  }
  if (params?.groups !== undefined) {
    url.searchParams.set("groups", String(params.groups));
  }
  return url.toString();
}

export function gameSummaryUrl(gameId: string): string {
  return `${ESPN_API_BASE}/summary?event=${gameId}`;
}

export function standingsUrl(params?: {
  year?: number;
  group?: number; // conference group ID
}): string {
  const url = new URL(
    "https://site.api.espn.com/apis/v2/sports/football/college-football/standings"
  );
  url.searchParams.set("season", String(params?.year ?? CURRENT_SEASON_YEAR));
  url.searchParams.set("type", "1"); // conference standings
  if (params?.group !== undefined) {
    url.searchParams.set("group", String(params.group));
  }
  return url.toString();
}

export function rankingsUrl(params?: { year?: number }): string {
  const url = new URL(`${ESPN_API_BASE}/rankings`);
  url.searchParams.set("season", String(params?.year ?? CURRENT_SEASON_YEAR));
  return url.toString();
}

export function teamUrl(teamId: string): string {
  return `${ESPN_API_BASE}/teams/${teamId}`;
}

export function teamRosterUrl(teamId: string): string {
  return `${ESPN_API_BASE}/teams/${teamId}/roster`;
}

export function teamScheduleUrl(
  teamId: string,
  params?: { year?: number }
): string {
  const url = new URL(`${ESPN_API_BASE}/teams/${teamId}/schedule`);
  url.searchParams.set("season", String(params?.year ?? CURRENT_SEASON_YEAR));
  return url.toString();
}
