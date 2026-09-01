// Server-side ESPN API bridge for the existing /api routes. Thin wrappers
// over the provider (provider.ts) that keep the legacy response shapes the
// routes and components already consume. New code should prefer the
// provider's domain methods directly.

import type { EspnStandingsResponse, EspnRankingsResponse } from "./types";
import { standingsUrl, rankingsUrl } from "./endpoints";
import { transformStandings, transformPolls } from "./transformers";
import { scoreboard, gameSummary } from "./provider";
import type {
  Game,
  GameDetail,
  RankingsData,
  PollType,
  ConferenceStanding,
} from "@/lib/types";

async function fetchJson<T>(url: string, revalidate: number): Promise<T> {
  const res = await fetch(url, { next: { revalidate } });
  if (!res.ok) {
    throw new Error(`ESPN API error ${res.status}: ${url}`);
  }
  return res.json() as Promise<T>;
}

export async function getScoreboard(params?: {
  week?: number;
  year?: number;
}): Promise<{ games: Game[]; week: number }> {
  const board = await scoreboard({
    weekValue: params?.week,
    seasonType: 2,
    year: params?.year,
  });
  return {
    games: board.games,
    week: board.currentWeekNumber ?? params?.week ?? 1,
  };
}

export async function getGameSummary(gameId: string): Promise<GameDetail> {
  return gameSummary(gameId);
}

const ESPN_POLL_MAP: Record<string, { type: PollType; label: string }> = {
  ap: { type: "ap", label: "AP Poll" },
  coaches: { type: "coaches", label: "Coaches' Poll" },
  cfp: { type: "cfp", label: "CFB Playoff" },
};

function matchPollType(
  espnType: string,
  espnName: string
): { type: PollType; label: string } | null {
  const t = espnType.toLowerCase();
  const n = espnName.toLowerCase();

  if (t === "ap" || n.includes("ap")) return ESPN_POLL_MAP.ap;
  if (t === "usa" || n.includes("coaches")) return ESPN_POLL_MAP.coaches;
  if (t === "cfp" || n.includes("playoff") || n.includes("cfp"))
    return ESPN_POLL_MAP.cfp;
  return null;
}

export async function getAllRankings(): Promise<RankingsData[]> {
  const data = await fetchJson<EspnRankingsResponse>(rankingsUrl(), 300);
  const polls = transformPolls(data);

  const results: RankingsData[] = [];
  for (const poll of polls) {
    const match = matchPollType(poll.type ?? "", poll.name);
    if (!match) continue;
    results.push({
      type: match.type,
      label: match.label,
      teams: poll.ranks,
    });
  }

  // Ensure a consistent order: cfp, ap, coaches
  const order: PollType[] = ["cfp", "ap", "coaches"];
  results.sort((a, b) => order.indexOf(a.type) - order.indexOf(b.type));

  return results;
}

export async function getRankings(): Promise<
  RankingsData["teams"]
> {
  const all = await getAllRankings();
  return (all.find((r) => r.type === "ap") ?? all[0])?.teams ?? [];
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
  return transformStandings(data).flatMap((g) => g.entries);
}
