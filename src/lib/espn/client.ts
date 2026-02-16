// Server-side ESPN API client
// All methods are async and meant to be called from API routes or server components.

import type {
  EspnScoreboardResponse,
  EspnGameSummaryResponse,
  EspnRankingsResponse,
  EspnStandingsResponse,
} from "./types";
import {
  scoreboardUrl,
  gameSummaryUrl,
  standingsUrl,
  rankingsUrl,
} from "./endpoints";
import {
  transformScoreboard,
  transformEvent,
  transformRankedTeam,
  transformStandingsEntry,
  transformGameSummary,
} from "./transformers";
import type {
  Game,
  GameDetail,
  RankedTeam,
  ConferenceStanding,
} from "@/lib/types";

async function fetchJson<T>(url: string, revalidate?: number): Promise<T> {
  const res = await fetch(url, {
    next: { revalidate: revalidate ?? 60 },
  });

  if (!res.ok) {
    throw new Error(`ESPN API error ${res.status}: ${url}`);
  }

  return res.json();
}

export async function getScoreboard(params?: {
  week?: number;
  year?: number;
}): Promise<{ games: Game[]; week: number }> {
  const url = scoreboardUrl({ ...params, groups: 80 }); // FBS
  const data = await fetchJson<EspnScoreboardResponse>(url, 30);

  return {
    games: transformScoreboard(data.events),
    week: data.week?.number ?? params?.week ?? 1,
  };
}

export async function getGameSummary(gameId: string): Promise<GameDetail> {
  // First get the scoreboard event to get the Game object
  const summaryUrl = gameSummaryUrl(gameId);
  const summary = await fetchJson<EspnGameSummaryResponse>(summaryUrl, 30);

  // The summary response includes header competitions which we can use to build the game
  const headerComp = summary.header?.competitions?.[0];
  if (!headerComp) {
    throw new Error(`No competition data found for game ${gameId}`);
  }

  // Build an event-like object from the header for transformation
  const game = transformEvent({
    id: gameId,
    date: headerComp.date,
    name: "",
    shortName: "",
    season: { year: new Date().getFullYear(), type: 2 },
    week: { number: 0 },
    competitions: [headerComp],
    status: headerComp.status,
  });

  return transformGameSummary(gameId, game, summary);
}

export async function getRankings(params?: {
  year?: number;
}): Promise<RankedTeam[]> {
  const url = rankingsUrl(params);
  const data = await fetchJson<EspnRankingsResponse>(url, 300);

  // Get AP Top 25 poll (usually first)
  const apPoll = data.rankings?.find(
    (r) => r.type === "ap" || r.name.includes("AP")
  ) ?? data.rankings?.[0];

  if (!apPoll) return [];

  return apPoll.ranks.map(transformRankedTeam);
}

export async function getStandings(params?: {
  conferenceId?: string;
  year?: number;
}): Promise<ConferenceStanding[]> {
  const group = params?.conferenceId
    ? parseInt(params.conferenceId, 10)
    : undefined;
  const url = standingsUrl({ year: params?.year, group });
  const data = await fetchJson<EspnStandingsResponse>(url, 300);

  const entries: ConferenceStanding[] = [];

  for (const child of data.children ?? []) {
    for (const entry of child.standings?.entries ?? []) {
      entries.push(transformStandingsEntry(entry));
    }
  }

  return entries;
}
