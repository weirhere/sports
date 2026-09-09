// The domain-facing provider — the web twin of the iOS `ScoresProviding`
// protocol (StatSideShared/Networking/ESPNClient.swift). Every method takes
// a league, all are server-side, and all return domain types; ESPN's shapes
// never leave this layer. Errors are typed and thrown, never retried —
// Next's fetch cache (`next.revalidate`) is the politeness throttle.

import type {
  Game,
  Poll,
  Scoreboard,
  ConferenceStandingsGroup,
  ConferenceTeams,
  GameDetail,
  TeamScheduleData,
} from "@/lib/types";
import {
  canTableAWholeSeason,
  hasPoll,
  seasonSpan,
  seasonYear as leagueSeasonYear,
  seasonYearFromEspn,
  type League,
} from "@/lib/leagues";
import type {
  EspnScoreboardResponse,
  EspnRankingsResponse,
  EspnStandingsResponse,
  EspnScheduleResponse,
  EspnGameSummaryResponse,
} from "./types";
import {
  dayWindowUrl,
  gameSummaryUrl,
  rankingsUrl,
  scoreboardUrl,
  seasonWindowUrl,
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
 * Read a scoreboard payload's own season onto our axis.
 *
 * A `dates=` request returns no calendar and pins `season.year` to the
 * *current* season whatever range it was asked for, so the caller's own
 * season wins wherever it has one.
 */
function scoreboardSeason(
  data: EspnScoreboardResponse,
  league: League
): number | undefined {
  const raw = data.season?.year;
  return raw !== undefined ? seasonYearFromEspn(league, raw) : undefined;
}

/**
 * One league's scoreboard for a span of days — the Scores screen's only
 * scoreboard request.
 *
 * The caller asks for a five-day window to answer for three: ESPN reads
 * `dates=` on the Eastern clock, and the two-day margin absorbs the
 * ET-to-local offset for every time zone.
 */
export async function scoreboardForDays(
  league: League,
  start: Date,
  end: Date,
  options?: { groups?: number }
): Promise<Scoreboard> {
  const url = dayWindowUrl(league, start, end, { groups: options?.groups });
  const data = await fetchJson<EspnScoreboardResponse>(
    url,
    REVALIDATE.scoreboard
  );
  const seasonYear = scoreboardSeason(data, league);
  return {
    league,
    seasonYear,
    seasonType: data.season?.type,
    currentWeekNumber: data.week?.number,
    weeks: transformCalendar(data),
    games: transformScoreboard(data.events ?? [], league, { seasonYear }),
  };
}

/**
 * One league's scoreboard for a week — still how a football league's own
 * pages ask, even though the Scores screen no longer does.
 */
export async function scoreboard(
  league: League,
  params?: {
    weekValue?: number;
    seasonType?: number;
    /** Only meaningful alongside a week — see `scoreboardUrl`. */
    year?: number;
    groups?: number;
  }
): Promise<Scoreboard> {
  const url = scoreboardUrl(league, {
    week: params?.weekValue,
    seasonType: params?.seasonType,
    seasonYear: params?.year,
    groups: params?.groups,
  });
  const data = await fetchJson<EspnScoreboardResponse>(
    url,
    REVALIDATE.scoreboard
  );
  // The caller's own season wins where it has one: a `dates=`-scoped
  // response pins `season.year` to the current season whatever it was
  // asked for.
  const seasonYear = params?.year ?? scoreboardSeason(data, league);
  return {
    league,
    seasonYear,
    seasonType: data.season?.type,
    currentWeekNumber: data.week?.number,
    weeks: transformCalendar(data),
    games: transformScoreboard(data.events ?? [], league, { seasonYear }),
  };
}

/** The league's polls. College football is the only one that has any. */
export async function rankings(league: League): Promise<Poll[]> {
  if (!hasPoll(league)) return [];
  const data = await fetchJson<EspnRankingsResponse>(
    rankingsUrl(league),
    REVALIDATE.rankings
  );
  return transformPolls(data, league);
}

/** A league's conferences with alphabetical rosters, for browsing. */
export async function conferenceTeams(
  league: League,
  options?: { group?: number; level?: number }
): Promise<ConferenceTeams[]> {
  const data = await fetchJson<EspnStandingsResponse>(
    standingsUrl(league, { group: options?.group, level: options?.level }),
    REVALIDATE.conferences
  );
  return transformConferenceTeams(data, league);
}

/**
 * All of a league's conference standings in one call, each in ESPN's
 * standings order (it encodes tiebreakers). Empty conferences are kept —
 * offseason responses can have zero entries and the page needs to say
 * "Standings TBA", not error. An explicit year returns exactly that season,
 * membership included.
 *
 * `level` walks ESPN's group tree: the shipped response stops at the
 * conferences, and `level: 3` is what reaches a pro league's divisions.
 */
export async function conferenceStandings(
  league: League,
  options?: { year?: number; group?: number; level?: number }
): Promise<ConferenceStandingsGroup[]> {
  const data = await fetchJson<EspnStandingsResponse>(
    standingsUrl(league, {
      year: options?.year,
      group: options?.group,
      level: options?.level,
    }),
    REVALIDATE.standings
  );
  return transformStandings(data, league);
}

/**
 * One team's schedule. An explicit year returns exactly that season — a
 * user who picked 2019 must never silently get 2018. A nil year means the
 * current season, falling back to last season only while the next is
 * unpublished (zero games).
 */
export async function teamSchedule(
  league: League,
  teamId: string,
  year?: number
): Promise<TeamScheduleData> {
  if (year !== undefined) {
    return fetchSchedule(league, teamId, year);
  }
  const current = leagueSeasonYear(league);
  const schedule = await fetchSchedule(league, teamId, current);
  if (schedule.games.length > 0) return schedule;
  // Next season's schedule isn't published yet; show last season instead.
  return fetchSchedule(league, teamId, current - 1);
}

async function fetchSchedule(
  league: League,
  teamId: string,
  year: number
): Promise<TeamScheduleData> {
  // Three season types in parallel. The preseason request is what surfaces
  // the Hall of Fame Game and August exhibitions — the client only ever
  // asked for 2 and 3, so a fan checking in mid-August had nothing to look
  // at. Both the preseason and postseason 404 for teams that don't have
  // one, which is tolerated rather than fatal.
  const [preseason, regular, postseason] = await Promise.all([
    fetchJson<EspnScheduleResponse>(
      teamScheduleUrl(league, teamId, { year, seasonType: 1 }),
      REVALIDATE.schedule
    ).catch(() => undefined),
    fetchJson<EspnScheduleResponse>(
      teamScheduleUrl(league, teamId, { year, seasonType: 2 }),
      REVALIDATE.schedule
    ),
    fetchJson<EspnScheduleResponse>(
      teamScheduleUrl(league, teamId, { year, seasonType: 3 }),
      REVALIDATE.schedule
    ).catch(() => undefined),
  ]);
  return transformTeamSchedule(regular, league, [
    ...(preseason?.events ?? []),
    ...(postseason?.events ?? []),
  ]);
}

/**
 * One conference's full-season slate — every game with a side in the
 * conference, postseason included.
 *
 * Fetched as a **date window over the season's own span**, never as
 * `dates={year}`: a bare year is the *calendar* year, so it opens the slate
 * with the previous January's bowls and truncates before December (verified
 * live 2026-09-05). The span is split at November 1 into two requests
 * because ESPN caps a window at 900 events and truncates silently rather
 * than paging.
 *
 * Only ever called for a league that can afford it — `groups=` is ignored
 * outside football, so there is no narrow fetch for the NBA or NHL and a
 * season-wide request there returns a truncated 12 MB.
 */
export async function conferenceGames(
  league: League,
  conferenceId: number,
  year?: number
): Promise<Game[]> {
  if (!canTableAWholeSeason(league)) return [];
  const seasonYear = year ?? leagueSeasonYear(league);
  const span = seasonSpan(league, seasonYear);
  const split = new Date(seasonYear, 10, 1); // November 1
  const halves: [Date, Date][] =
    split > span.start && split < span.end
      ? [
          [span.start, new Date(seasonYear, 9, 31)],
          [split, span.end],
        ]
      : [[span.start, span.end]];

  const responses = await Promise.all(
    halves.map(([start, end]) =>
      fetchJson<EspnScoreboardResponse>(
        seasonWindowUrl(league, start, end, { groups: conferenceId }),
        REVALIDATE.conferenceGames
      )
    )
  );

  const seen = new Set<string>();
  const games: Game[] = [];
  for (const data of responses) {
    for (const game of transformScoreboard(data.events ?? [], league, {
      seasonYear,
    })) {
      if (seen.has(game.id)) continue;
      seen.add(game.id);
      games.push(game);
    }
  }
  return games;
}

export async function gameSummary(
  league: League,
  eventId: string
): Promise<GameDetail> {
  const data = await fetchJson<EspnGameSummaryResponse>(
    gameSummaryUrl(league, eventId),
    REVALIDATE.gameSummary
  );
  const game = transformHeaderGame(eventId, data, league);
  if (!game) {
    throw new EspnDataError(`No competition data found for game ${eventId}`);
  }
  return transformGameSummary(eventId, game, data);
}
