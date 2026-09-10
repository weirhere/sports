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
  Team,
  TeamScheduleData,
} from "@/lib/types";
import {
  canTableAWholeSeason,
  hasCollegeDivisions,
  hasPoll,
  seasonSpan,
  seasonYear as leagueSeasonYear,
  seasonYearFromEspn,
  type League,
} from "@/lib/leagues";
import type {
  EspnScoreboardResponse,
  EspnCoreCollection,
  EspnCoreRanking,
  EspnRankingsResponse,
  EspnTeamsResponse,
  EspnStandingsResponse,
  EspnScheduleResponse,
  EspnGameSummaryResponse,
} from "./types";
import {
  coreRankingUrl,
  coreWeeksUrl,
  dayWindowUrl,
  gameSummaryUrl,
  rankingsUrl,
  scoreboardUrl,
  seasonWindowUrl,
  standingsUrl,
  teamScheduleUrl,
  teamsUrl,
} from "./endpoints";
import { addDays, startOfDay } from "@/lib/day";
import { FBS_GROUP_ID } from "@/lib/conferences";
import { tableMatches, type FollowedTable } from "@/lib/followed-tables";
import {
  transformCoreRanking,
  transformTeamDirectory,
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
export async function rankings(
  league: League,
  year?: number
): Promise<Poll[]> {
  if (!hasPoll(league)) return [];
  // The site endpoint is latest-only: it ignores `season`, `week`, `year`
  // and `dates` alike and always answers with the newest poll it has (probed
  // live 2026-09-05). So it can speak for the season in progress and nothing
  // else — a past season goes to the core API instead.
  if (year === undefined || year === leagueSeasonYear(league)) {
    const data = await fetchJson<EspnRankingsResponse>(
      rankingsUrl(league),
      REVALIDATE.rankings
    );
    return transformPolls(data, league);
  }
  return finalRankings(league, year);
}

/** Poll ids in ESPN's core API: AP, Coaches, CFP. */
const CORE_POLL_AP = 1;
const CORE_POLL_COACHES = 2;
const CORE_POLL_CFP = 21;

/**
 * A finished season's closing polls, from ESPN's core API — the one surface
 * that carries a season/week axis for rankings.
 *
 * Two shapes' worth, not one: the AP and Coaches polls end in the postseason
 * (`types/3/weeks/1`, headlined "Final Rankings"), while the CFP's last table
 * is selection day's — the final week of the *regular* season, since a
 * postseason CFP table is a 404. All three resolve for every season back to
 * the 2014 floor (verified live 2026-09-05).
 *
 * A poll that doesn't come back is dropped rather than failing the season;
 * all three missing is the season failing. An **empty directory** is the same
 * failure as no poll at all — it would name none of the 25, and a retry beats
 * a table of dashes.
 */
async function finalRankings(league: League, year: number): Promise<Poll[]> {
  const [directory, ap, coaches, cfp] = await Promise.all([
    teamDirectory(league),
    coreRanking(league, { year, seasonType: 3, week: 1, rankingId: CORE_POLL_AP }),
    coreRanking(league, {
      year,
      seasonType: 3,
      week: 1,
      rankingId: CORE_POLL_COACHES,
    }),
    finalCfpRanking(league, year),
  ]);
  const found = [ap, coaches, cfp].filter(
    (ranking): ranking is EspnCoreRanking => ranking !== undefined
  );
  if (found.length === 0 || directory.size === 0) {
    throw new EspnDataError(`No rankings for ${year}`);
  }
  return found
    .map((ranking) => transformCoreRanking(ranking, league, directory))
    .filter((poll): poll is Poll => poll !== null);
}

/**
 * The CFP's closing table, whose week is the season's last *regular* one —
 * 15 or 16 depending on the year, so it is read off the weeks collection
 * rather than assumed.
 */
async function finalCfpRanking(
  league: League,
  year: number
): Promise<EspnCoreRanking | undefined> {
  const weeks = await fetchJson<EspnCoreCollection>(
    coreWeeksUrl(league, { year, seasonType: 2 }),
    REVALIDATE.rankings
  ).catch(() => undefined);
  const last = weeks?.count;
  if (!last || last <= 0) return undefined;
  return coreRanking(league, {
    year,
    seasonType: 2,
    week: last,
    rankingId: CORE_POLL_CFP,
  });
}

function coreRanking(
  league: League,
  params: { year: number; seasonType: number; week: number; rankingId: number }
): Promise<EspnCoreRanking | undefined> {
  return fetchJson<EspnCoreRanking>(
    coreRankingUrl(league, params),
    REVALIDATE.rankings
  ).catch(() => undefined);
}

/**
 * Every team ESPN knows, by id — one request, cached like a directory
 * because that is what it is. Team names don't change inside a session.
 */
async function teamDirectory(league: League): Promise<Map<string, Team>> {
  const data = await fetchJson<EspnTeamsResponse>(
    teamsUrl(league),
    REVALIDATE.conferences
  ).catch(() => undefined);
  return transformTeamDirectory(data, league);
}

/**
 * A whole division's season — every FBS game, which is what makes the Top
 * 25's Games tab a filter over one slate rather than 25 schedule fetches.
 *
 * ESPN reads the FBS group as a conference, so this is `conferenceGames`
 * against group 80 — the same two-request season window, split at November 1
 * because a full FBS season is ~950 events against a 900 cap.
 */
export async function seasonGames(
  league: League,
  year?: number
): Promise<Game[]> {
  return conferenceGames(league, FBS_GROUP_ID, year);
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
 * Every table a league's hub row lists, in one request.
 *
 * The pro leagues ask for the **divisional** response (`level=3`) and fold
 * the conferences back out of it, rather than asking for both: the hub
 * lists divisions now (a division is the race a team is actually in, where
 * a conference is a seeding pool), and folding costs nothing where a second
 * request would cost three more on every hub load.
 *
 * College football asks the shipped response — its conferences have no
 * divisions to reach for, and its two *divisions* (FBS and FCS) are
 * separate `group=` requests the caller makes side by side so either can
 * fail alone.
 */
export async function hubStandings(
  league: League,
  options?: { year?: number; group?: number }
): Promise<ConferenceStandingsGroup[]> {
  if (hasCollegeDivisions(league)) {
    // College football's conferences nest only in a divisional era, and
    // the shipped response already carries those divisions.
    return conferenceStandings(league, {
      year: options?.year,
      group: options?.group,
    });
  }

  // **Both** responses, in parallel. The divisional one is what the hub
  // lists and what a Division scope tables — but its conference groups
  // arrive empty, so folding them back up produces a table whose entries
  // are each division's in turn. That table ranks *nothing* across them,
  // and printing a place column over it is exactly the tiebreaker
  // guesswork the standings contract forbids. The shipped response has the
  // real conference order, so that is what a Conference scope shows.
  const [conferences, divisions] = await Promise.all([
    conferenceStandings(league, { year: options?.year }),
    conferenceStandings(league, { year: options?.year, level: 3 }),
  ]);
  return [...conferences, ...divisions];
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
  return transformTeamSchedule(regular, league, {
    preseason: preseason?.events,
    postseason: postseason?.events,
  });
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
  const seasonYear = year ?? leagueSeasonYear(league);
  if (!canTableAWholeSeason(league)) {
    return rollingConferenceGames(league, conferenceId, seasonYear);
  }
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

/** How many windows forward a Games tab looks before giving up. */
const ROLLING_WINDOW_PROBES = 4;

/**
 * The slate for a league whose season is too big to fetch whole: one
 * `dates=` window around today, narrowed to this page's teams.
 *
 * A season-long request for the NBA returns exactly **900 events and 12 MB**
 * and truncates silently in February (probed live 2026-09-08), and ESPN
 * ignores `groups=` outside football — so there is no narrow fetch to fall
 * back on and the narrowing happens here. It runs through the same rule
 * that decides whether a followed table claims a game, so a division's page
 * and a division follow can never disagree about which games are its; a
 * league-wide page keeps them all, because every team's chain reaches its
 * league.
 *
 * A week back and three weeks forward answers "when do they play next" and
 * "what did I miss" in one request of about a megabyte. The alternative is
 * nine monthly requests and 24 MB for a page view, which is not a tab, it is
 * a download.
 *
 * The window walks forward until one has games in it, the way the day
 * strip's own probe does: in September the NBA's next game is three weeks
 * past the end of the first window, and a tab saying "Schedule TBA" three
 * weeks before tip-off answers the wrong question. A finished season reads
 * from its **opening** instead of from today, which is nowhere near it.
 */
async function rollingConferenceGames(
  league: League,
  conferenceId: number,
  year: number
): Promise<Game[]> {
  const span = seasonSpan(league, year);
  const table: FollowedTable = {
    kind: "conference",
    ref: { league, id: conferenceId },
  };
  const isCurrent = year === leagueSeasonYear(league);
  let start = isCurrent ? addDays(startOfDay(new Date()), -7) : span.start;

  for (let probe = 0; probe < ROLLING_WINDOW_PROBES; probe += 1) {
    if (start > span.end) return [];
    const end = addDays(start, 28);
    const board = await scoreboardForDays(
      league,
      start,
      end > span.end ? span.end : end
    );
    const games = board.games.filter((game) => tableMatches(table, game));
    if (games.length > 0) return games;
    start = end;
  }
  return [];
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
