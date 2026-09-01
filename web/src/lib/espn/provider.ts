// The domain-facing provider — the web twin of the iOS `ScoresProviding`
// protocol (StatSideShared/Networking/ESPNClient.swift). Seven methods, all
// server-side, all returning domain types; ESPN's shapes never leave this
// layer. Errors are typed and thrown, never retried — Next's fetch cache
// (`next.revalidate`) is the politeness throttle.

import type {
  Game,
  Poll,
  Scoreboard,
  ConferenceStandingsGroup,
  ConferenceTeams,
  GameDetail,
  TeamScheduleData,
} from "@/lib/types";
import { cfbSeasonYear } from "@/lib/season";
import type {
  EspnScoreboardResponse,
  EspnRankingsResponse,
  EspnStandingsResponse,
  EspnScheduleResponse,
  EspnGameSummaryResponse,
} from "./types";
import {
  scoreboardUrl,
  gameSummaryUrl,
  rankingsUrl,
  standingsUrl,
  teamScheduleUrl,
} from "./endpoints";
import {
  transformScoreboard,
  transformCalendar,
  transformPolls,
  transformStandings,
  transformConferenceTeams,
  transformTeamSchedule,
  transformHeaderGame,
  transformGameSummary,
} from "./transformers";

/** A non-2xx response from ESPN. */
export class EspnApiError extends Error {
  readonly status: number;
  readonly url: string;

  constructor(status: number, url: string) {
    super(`ESPN API error ${status}: ${url}`);
    this.name = "EspnApiError";
    this.status = status;
    this.url = url;
  }
}

/** Thrown when a response decodes but carries nothing usable. */
export class EspnDataError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "EspnDataError";
  }
}

// Cache lifetimes (seconds) per endpoint class — scoreboard and live game
// detail at the app's 30s polling floor, slow-moving data much longer.
const REVALIDATE = {
  scoreboard: 30,
  gameSummary: 30,
  rankings: 300,
  standings: 300,
  schedule: 3600,
  conferenceGames: 3600,
  conferences: 86400,
} as const;

async function fetchJson<T>(url: string, revalidate: number): Promise<T> {
  const res = await fetch(url, { next: { revalidate } });
  if (!res.ok) {
    throw new EspnApiError(res.status, url);
  }
  return res.json() as Promise<T>;
}

/**
 * Fetch the scoreboard. Pass nothing to get ESPN's current week; `year`
 * selects a season — always paired with an explicit week upstream.
 */
export async function scoreboard(params?: {
  weekValue?: number;
  seasonType?: number;
  year?: number;
}): Promise<Scoreboard> {
  const url = scoreboardUrl({
    week: params?.weekValue,
    seasonType: params?.seasonType,
    year: params?.year,
  });
  const data = await fetchJson<EspnScoreboardResponse>(
    url,
    REVALIDATE.scoreboard
  );
  return {
    seasonYear: data.season?.year,
    seasonType: data.season?.type,
    currentWeekNumber: data.week?.number,
    weeks: transformCalendar(data),
    games: transformScoreboard(data.events ?? [], {
      seasonYear: data.season?.year,
    }),
  };
}

export async function rankings(): Promise<Poll[]> {
  const data = await fetchJson<EspnRankingsResponse>(
    rankingsUrl(),
    REVALIDATE.rankings
  );
  return transformPolls(data);
}

/** FBS conferences with alphabetical rosters, for browsing. */
export async function fbsConferences(): Promise<ConferenceTeams[]> {
  const data = await fetchJson<EspnStandingsResponse>(
    standingsUrl(),
    REVALIDATE.conferences
  );
  return transformConferenceTeams(data);
}

/**
 * All FBS conferences' standings in one call, each in ESPN's standings
 * order (it encodes tiebreakers). Empty conferences are kept — offseason
 * responses can have zero entries and the page needs to say "Standings
 * TBA", not error. `year` selects a season; an explicit year returns
 * exactly that season — membership included.
 */
export async function conferenceStandings(
  year?: number
): Promise<ConferenceStandingsGroup[]> {
  const data = await fetchJson<EspnStandingsResponse>(
    standingsUrl({ year }),
    REVALIDATE.standings
  );
  return transformStandings(data);
}

/**
 * One team's schedule. An explicit year returns exactly that season — a
 * user who picked 2019 must never silently get 2018. A nil year means the
 * current season, falling back to last season only while the next is
 * unpublished (zero games).
 */
export async function teamSchedule(
  teamId: string,
  year?: number
): Promise<TeamScheduleData> {
  if (year !== undefined) {
    return fetchSchedule(teamId, year);
  }
  const current = cfbSeasonYear();
  const schedule = await fetchSchedule(teamId, current);
  if (schedule.games.length > 0) return schedule;
  // Next season's schedule isn't published yet; show last season instead.
  return fetchSchedule(teamId, current - 1);
}

async function fetchSchedule(
  teamId: string,
  year: number
): Promise<TeamScheduleData> {
  const regularPromise = fetchJson<EspnScheduleResponse>(
    teamScheduleUrl(teamId, { year, seasonType: 2 }),
    REVALIDATE.schedule
  );
  // The postseason request 404s for teams that didn't make one — tolerated.
  const postseasonPromise = fetchJson<EspnScheduleResponse>(
    teamScheduleUrl(teamId, { year, seasonType: 3 }),
    REVALIDATE.schedule
  ).catch(() => undefined);
  const [regular, postseason] = await Promise.all([
    regularPromise,
    postseasonPromise,
  ]);
  return transformTeamSchedule(regular, postseason?.events ?? []);
}

/**
 * One conference's full-season slate — every game with a side in the
 * conference, postseason included. `dates={year}` widens the scoreboard to
 * the whole season (types 2 and 3 arrive together, each event stamped with
 * its own week); a conference's season runs ~100–200 events, so one
 * 400-cap request covers it.
 */
export async function conferenceGames(
  conferenceId: number,
  year?: number
): Promise<Game[]> {
  const seasonYear = year ?? cfbSeasonYear();
  const url = scoreboardUrl({
    groups: conferenceId,
    limit: 400,
    year: seasonYear,
  });
  const data = await fetchJson<EspnScoreboardResponse>(
    url,
    REVALIDATE.conferenceGames
  );
  return transformScoreboard(data.events ?? [], { seasonYear });
}

export async function gameSummary(eventId: string): Promise<GameDetail> {
  const data = await fetchJson<EspnGameSummaryResponse>(
    gameSummaryUrl(eventId),
    REVALIDATE.gameSummary
  );
  const game = transformHeaderGame(eventId, data);
  if (!game) {
    throw new EspnDataError(`No competition data found for game ${eventId}`);
  }
  return transformGameSummary(eventId, game, data);
}
