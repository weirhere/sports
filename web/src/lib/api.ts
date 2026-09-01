import type {
  Game,
  GameDetail,
  ConferenceStanding,
  RankingsData,
  Team,
} from "./types";

const BASE = "/api";

async function fetchJson<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

export async function getSchedule(
  week?: number,
  year?: number
): Promise<{ games: Game[]; week: number }> {
  const params = new URLSearchParams();
  if (week !== undefined) params.set("week", String(week));
  if (year !== undefined) params.set("year", String(year));
  return fetchJson(`${BASE}/schedule?${params}`);
}

export async function getGameDetail(gameId: string): Promise<GameDetail> {
  return fetchJson(`${BASE}/game/${gameId}`);
}

export async function getPlayByPlay(
  gameId: string
): Promise<GameDetail["plays"]> {
  return fetchJson(`${BASE}/game/${gameId}/play-by-play`);
}

export async function getStandings(
  conferenceId?: string
): Promise<ConferenceStanding[]> {
  const params = conferenceId ? `?conferenceId=${conferenceId}` : "";
  return fetchJson(`${BASE}/standings${params}`);
}

export async function getRankings(): Promise<RankingsData[]> {
  return fetchJson(`${BASE}/rankings`);
}

export async function getAllTeams(): Promise<Team[]> {
  return fetchJson(`${BASE}/teams`);
}

export async function getTeamSchedule(teamId: string): Promise<Game[]> {
  return fetchJson(`${BASE}/teams/${teamId}/schedule`);
}
