import type {
  Game,
  GameDetail,
  ConferenceStanding,
  RankingsData,
  Scoreboard,
  Team,
} from "./types";

const BASE = "/api";

async function fetchJson<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

/**
 * Fetch the scoreboard. No `slot` means ESPN's current week; `year` selects
 * a season (the payload then carries that season's own `weeks` calendar).
 */
export async function getScoreboard(
  slot?: { value: number; seasonType: number },
  year?: number
): Promise<Scoreboard> {
  const params = new URLSearchParams();
  if (slot !== undefined) {
    params.set("week", String(slot.value));
    params.set("seasontype", String(slot.seasonType));
  }
  if (year !== undefined) params.set("year", String(year));
  const query = params.toString();
  return fetchJson(`${BASE}/scoreboard${query ? `?${query}` : ""}`);
}

export async function getGameDetail(gameId: string): Promise<GameDetail> {
  return fetchJson(`${BASE}/game/${gameId}`);
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
