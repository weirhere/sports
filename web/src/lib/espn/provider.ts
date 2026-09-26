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
  TeamRoster,
  TeamScheduleData,
} from "@/lib/types";
import {
  SEASON_FLOOR,
  belongsToSeason,
  hasCollegeDivisions,
  hasPoll,
  headToHeadSeasons,
  seasonGamesSpan,
  seasonYear as leagueSeasonYear,
  seasonYearFromEspn,
  seasonYears,
  type League,
} from "@/lib/leagues";
import { makeHeadToHead, type HeadToHead } from "@/lib/head-to-head";
import {
  assembleTrophyCase,
  deriveTrophies,
  type TrophyCase,
} from "@/lib/trophies";
import {
  registryCoveredKinds,
  registryTrophies,
} from "@/lib/trophy-registry";
import type {
  EspnScoreboardResponse,
  EspnCoreCollection,
  EspnCoreRanking,
  EspnRankingsResponse,
  EspnTeamsResponse,
  EspnStandingsResponse,
  EspnScheduleResponse,
  EspnGameSummaryResponse,
  EspnRosterResponse,
} from "./types";
import {
  coreRankingUrl,
  coreWeeksUrl,
  dayWindowUrl,
  espnDay,
  espnDayTokens,
  espnMonthTokens,
  espnWindow,
  gameSummaryUrl,
  rankingsUrl,
  scoreboardUrl,
  seasonWindowUrl,
  standingsUrl,
  WINDOW_LIMIT,
  teamRosterUrl,
  teamScheduleUrl,
  teamsUrl,
} from "./endpoints";
import { FBS_GROUP_ID } from "@/lib/conferences";
import {
  transformCoreRanking,
  transformTeamDirectory,
  transformScoreboard,
  transformCalendar,
  transformPolls,
  transformStandings,
  transformConferenceTeams,
  transformTeamSchedule,
  transformRoster,
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

// Cache lifetimes (seconds) per endpoint class. Scoreboard and game summary
// are 1s, the client's live poll and the shortest lifetime Next's data
// cache takes: it still coalesces every visitor's tick into one ESPN request
// a second. Next serves one stale copy while it revalidates, so a live row
// can trail ESPN by one tick. Slow-moving data keeps much longer lifetimes.
const REVALIDATE = {
  scoreboard: 1,
  gameSummary: 1,
  rankings: 300,
  standings: 300,
  schedule: 3600,
  roster: 3600,
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
 * One league's games on ESPN's own days, named by their `dates=` tokens —
 * the Scores screen's live poll (2026-09-26).
 *
 * The browser works out which Eastern days hold a game in play and sends
 * their tokens, so nothing here reads the host's clock and nothing is
 * clipped: a token *is* the day ESPN answers for.
 */
export async function scoreboardForDateTokens(
  league: League,
  tokens: readonly string[],
  options?: { groups?: number }
): Promise<Game[]> {
  const responses = await Promise.all(
    tokens.map((dates) =>
      fetchJson<EspnScoreboardResponse>(
        dayWindowUrl(league, dates, { groups: options?.groups }),
        REVALIDATE.scoreboard
      )
    )
  );
  const [first] = responses;
  const seasonYear = first ? scoreboardSeason(first, league) : undefined;
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
  // One request per token, because ESPN withdrew the range form — five
  // days is five requests, and a sweep wider than a week goes monthly.
  // Any one of them failing fails the window: the caller records its inner
  // days as loaded whether or not they came back carrying games, so a
  // swallowed failure would file as "no games today", which is the one
  // answer worse than an error.
  const tokens = espnWindow(start, end);
  const responses = await Promise.all(
    tokens.map((dates) =>
      fetchJson<EspnScoreboardResponse>(
        dayWindowUrl(league, dates, { groups: options?.groups }),
        REVALIDATE.scoreboard
      )
    )
  );
  // The first token's payload speaks for the window's season metadata, the
  // way the whole range's used to; a later one can only repeat it.
  const [first] = responses;
  const seasonYear = first ? scoreboardSeason(first, league) : undefined;
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
  return {
    league,
    seasonYear,
    seasonType: first?.season?.type,
    currentWeekNumber: first?.week?.number,
    weeks: first ? transformCalendar(first) : [],
    games: clipGames(games, start, end),
  };
}

/**
 * A slate narrowed to the days actually asked for.
 *
 * Monthly tokens over-fetch by up to a month at each end, and both callers
 * mind: the Scores screen buckets by day and would file a neighbouring
 * month's games under days it never asked about, and a season span that
 * opens mid-month would pull in the previous season's tail.
 *
 * Read with `espnDay`, the same spelling the tokens are built from, so the
 * clip and the request can never disagree about which day a game is on. A
 * kickoff that won't parse can't be placed either side of the line, and
 * dropping it would thin a slate over a malformed field alone.
 */
function clipGames(games: Game[], start: Date, end: Date): Game[] {
  const from = espnDay(start);
  const to = espnDay(end);
  return games.filter((game) => {
    const at = new Date(game.scheduledAt);
    if (Number.isNaN(at.getTime())) return true;
    const token = espnDay(at);
    return token >= from && token <= to;
  });
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
 * against group 80 — the same month-by-month fetch, six requests for
 * August through January.
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

/**
 * One team's current roster.
 *
 * No `year`, deliberately: ESPN's roster endpoint has no season axis.
 * `?season=2019`, `?season=2024` and `?season=2025` all answer 200, echo the
 * season back, and carry zero athletes (probed live 2026-09-10). Which is
 * also why the Roster tab shows no season chip.
 *
 * Cached for an hour like the schedule and never polled — a roster doesn't
 * change during a game.
 */
export async function teamRoster(
  league: League,
  teamId: string
): Promise<TeamRoster> {
  const data = await fetchJson<EspnRosterResponse>(
    teamRosterUrl(league, teamId),
    REVALIDATE.roster
  );
  return transformRoster(data);
}

async function fetchSchedule(
  league: League,
  teamId: string,
  year: number,
  options?: { preseason?: boolean }
): Promise<TeamScheduleData> {
  // Three season types in parallel. The preseason request is what surfaces
  // the Hall of Fame Game and August exhibitions — the client only ever
  // asked for 2 and 3, so a fan checking in mid-August had nothing to look
  // at. Both the preseason and postseason 404 for teams that don't have
  // one, which is tolerated rather than fatal.
  //
  // A caller that has no use for the exhibitions skips that request rather
  // than filtering it out afterwards: the difference is a round trip, not a
  // predicate, and a series ten seasons deep is where that saving is worth
  // having.
  const wantsPreseason = options?.preseason ?? true;
  const [preseason, regular, postseason] = await Promise.all([
    wantsPreseason
      ? fetchJson<EspnScheduleResponse>(
          teamScheduleUrl(league, teamId, { year, seasonType: 1 }),
          REVALIDATE.schedule
        ).catch(() => undefined)
      : undefined,
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
 * One team's season, minus the exhibitions — the unit a head-to-head series
 * and a trophy case are both assembled from.
 *
 * Its own function rather than a filter over `teamSchedule` because the
 * difference is a request: ESPN files each phase separately, and skipping the
 * preseason one takes college football's ten-season series from 30 requests
 * to 20.
 */
export async function teamSeasonGames(
  league: League,
  teamId: string,
  year: number
): Promise<TeamScheduleData> {
  return fetchSchedule(league, teamId, year, { preseason: false });
}

/**
 * How many season requests are in flight at once.
 *
 * Bounded rather than fired off together: ten seasons is twenty requests, and
 * twenty at once is not what "be a polite guest" means even for a one-shot.
 * This just makes the throttle ours and deliberate, at a width that still
 * hides the round-trip latency.
 */
const SEASON_POOL_WIDTH = 3;

/**
 * Walk a span of seasons a few at a time, dropping the ones that fail.
 *
 * A season that fails is dropped rather than failing the walk; a walk where
 * *every* season failed throws, because an empty answer and a broken one look
 * identical on screen and only one of them should say "no meetings".
 */
async function walkSeasons<T>(
  years: number[],
  task: (year: number) => Promise<T>
): Promise<T[]> {
  const collected: T[] = [];
  let succeeded = false;
  let next = 0;

  async function worker(): Promise<void> {
    for (;;) {
      const index = next;
      next += 1;
      if (index >= years.length) return;
      try {
        collected.push(await task(years[index]));
        succeeded = true;
      } catch {
        // Dropped: one dead season is not a dead series.
      }
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(SEASON_POOL_WIDTH, years.length) }, worker)
  );
  if (years.length > 0 && !succeeded) {
    throw new EspnDataError("No seasons could be fetched");
  }
  return collected;
}

/**
 * The completed meetings between the two sides of `game`, newest first, with
 * the tally they add up to.
 *
 * ESPN publishes no head-to-head resource. The site summary's `seasonseries`
 * is the closest thing and it is not close: it carries *this season's*
 * meetings only, and college football's summary ships none at all. So a series
 * worth a tab is walked out of one team's schedules, one season at a time.
 *
 * Anchored on the game's own season and looking back `headToHeadSeasons` of
 * them — so a 2019 page shows the series as it stood in 2019 rather than
 * everything that has happened since.
 *
 * Only one team's schedules are fetched: a meeting is in both sides'
 * schedules, so asking twice would double the bill to learn nothing. The home
 * side is the one asked, arbitrarily — a neutral-site game has no home in any
 * meaningful sense and both are equally covered.
 */
export async function headToHead(
  league: League,
  game: Game
): Promise<HeadToHead> {
  const kickoff = Date.parse(game.scheduledAt);
  const anchorSeason = leagueSeasonYear(
    league,
    Number.isNaN(kickoff) ? new Date() : new Date(kickoff)
  );
  const earliest = anchorSeason - headToHeadSeasons(league) + 1;
  const years: number[] = [];
  for (let year = earliest; year <= anchorSeason; year += 1) years.push(year);

  const seasons = await walkSeasons(years, (year) =>
    teamSeasonGames(league, game.homeTeam.team.id, year)
  );
  return makeHeadToHead(
    seasons.flatMap((season) => season.games),
    game,
    earliest
  );
}

/**
 * A team's whole shelf: every season back to the floor, derived, plus the
 * registry's closed history.
 *
 * Every season at once is what a trophy case *is*, which is also why the tab
 * shows no season chip — scoping it to one would turn it into a worse copy of
 * that season's Games tab. Twelve seasons is the bill; it is paid on an
 * explicit tab open, and Next's fetch cache holds each season's two requests
 * for an hour across every visitor.
 */
export async function teamTrophyCase(
  league: League,
  teamId: string
): Promise<TrophyCase> {
  const years = seasonYears(league);
  const derived = await walkSeasons(years, async (year) => {
    const schedule = await teamSeasonGames(league, teamId, year);
    return deriveTrophies(schedule.games, {
      teamId,
      // The payload's own year wins where it has one — a season ESPN
      // renumbers must not file its title under the year we asked for.
      year: schedule.year ?? year,
      league,
    });
  });
  return assembleTrophyCase({
    derived: derived.flat(),
    registry: registryTrophies(teamId, league),
    allTimeKinds: registryCoveredKinds(league),
    derivedFloor: SEASON_FLOOR,
  });
}

/**
 * One conference's full-season slate — every game with a side in the
 * conference, postseason included.
 *
 * Fetched **month by month over the season's own span**, never as
 * `dates={year}`: a bare year is the *calendar* year, so it opens the slate
 * with the previous January's bowls and truncates before December (verified
 * live 2026-09-05).
 *
 * The month is the granularity because the range form that used to state a
 * span whole was withdrawn (2026-09-17), and it replaces the November 1
 * split — which was a college-football date wearing the shape of a rule,
 * and which iOS had already retired. ESPN still truncates at `limit`
 * silently rather than paging, so a month that comes back at
 * `WINDOW_LIMIT` is re-asked as its own days, the one granularity below it.
 * Measured live 2026-09-17: college football's September is 323 events and
 * the NHL's January 231, so the fan-out is a guard that does not fire in
 * normal operation.
 *
 * **Every league tables its whole season** — the NBA and NHL included, which
 * until 2026-09-25 had a rolling four-week window here instead. That window
 * was sized against an unscoped, season-long `dates=` range that truncated
 * at 900 events; `groups=` narrows every league (iOS, 2026-09-10) and a
 * month is at most ~240 events league-wide (re-measured 2026-09-25), so
 * there is no league left whose season cannot be asked for. The bill is one
 * request per month of the span: 6 for college football, 8 for the NFL, 10
 * for basketball and hockey, each cached for an hour across every visitor.
 *
 * The span is `seasonGamesSpan`, not the day strip's: the pandemic seasons
 * ran months past their rollover, and the next season's span then overlaps
 * the bubble. Events are kept only when ESPN stamps them with this season.
 */
export async function conferenceGames(
  league: League,
  conferenceId: number,
  year?: number
): Promise<Game[]> {
  const seasonYear = year ?? leagueSeasonYear(league);
  const span = seasonGamesSpan(league, seasonYear);
  const months = espnMonthTokens(span.start, span.end);

  const perMonth = await Promise.all(
    months.map((month) =>
      seasonWindowEvents(league, month, conferenceId).then((events) =>
        // A month at the limit came back truncated — there is no flag, no
        // count and no cursor, so the count *is* the signal — and its own
        // days are the only way left to ask for less than a month.
        events.length >= WINDOW_LIMIT
          ? Promise.all(
              espnDayTokens(
                new Date(Number(month.slice(0, 4)), Number(month.slice(4)) - 1, 1),
                new Date(Number(month.slice(0, 4)), Number(month.slice(4)), 0)
              ).map((day) => seasonWindowEvents(league, day, conferenceId))
            ).then((byDay) => byDay.flat())
          : events
      )
    )
  );

  const seen = new Set<string>();
  const games: Game[] = [];
  const events = perMonth
    .flat()
    .filter((event) => belongsToSeason(league, seasonYear, event.season?.year));
  for (const game of transformScoreboard(events, league, { seasonYear })) {
    if (seen.has(game.id)) continue;
    seen.add(game.id);
    games.push(game);
  }
  // Months are whole and a season span need not be — the clip is what keeps
  // a neighbouring season's tail out.
  return clipGames(games, span.start, span.end);
}

/** One `dates=` token's worth of raw events, whatever its granularity. */
async function seasonWindowEvents(
  league: League,
  dates: string,
  groups: number
): Promise<NonNullable<EspnScoreboardResponse["events"]>> {
  const data = await fetchJson<EspnScoreboardResponse>(
    seasonWindowUrl(league, dates, { groups }),
    REVALIDATE.conferenceGames
  );
  return data.events ?? [];
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
