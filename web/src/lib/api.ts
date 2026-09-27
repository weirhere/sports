import type { Game, GameDetail, Scoreboard } from "./types";
import type { HeadToHead } from "./head-to-head";
import type { TrophyCase } from "./trophies";
import type { PlayerGameLog } from "./player-stats";
import { LEAGUES, type League } from "./leagues";
import type { NewsStory } from "./news";
import { parseFollowKey, type TeamRef } from "./refs";
import { forYou, toppedUp } from "./espn/news";
import { dayId } from "./day";

const BASE = "/api";

/**
 * A failed call to our own API, carrying the upstream status where the
 * route knew one.
 *
 * The route maps every ESPN failure to a flat 502, which told the browser
 * only that something went wrong — and "something went wrong" is what the
 * Scores screen had to print. `upstreamStatus` is ESPN's own answer, and
 * it is the difference between "they moved the endpoint" and "ESPN is
 * down".
 */
export class ApiError extends Error {
  readonly status: number;
  readonly upstreamStatus?: number;

  constructor(status: number, upstreamStatus?: number) {
    super(
      upstreamStatus === undefined
        ? `API error: ${status}`
        : `API error: ${status} (upstream ${upstreamStatus})`
    );
    this.name = "ApiError";
    this.status = status;
    this.upstreamStatus = upstreamStatus;
  }
}

async function fetchJson<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) {
    let upstreamStatus: number | undefined;
    try {
      const body: unknown = await res.json();
      const reported = (body as { upstreamStatus?: unknown })?.upstreamStatus;
      if (typeof reported === "number") upstreamStatus = reported;
    } catch {
      // No JSON body, or an empty one. The status alone will have to do.
    }
    throw new ApiError(res.status, upstreamStatus);
  }
  return res.json();
}

/**
 * Fetch the scoreboard. No `slot` means ESPN's current week.
 *
 * `league` is required, not defaulted: it selects the ESPN base URL, and a
 * missing one is a 400 rather than a quiet fall back to college football.
 */
export async function getScoreboard(
  league: League,
  slot?: { value: number; seasonType: number },
  year?: number
): Promise<Scoreboard> {
  const params = new URLSearchParams({ league });
  if (slot !== undefined) {
    params.set("week", String(slot.value));
    params.set("seasontype", String(slot.seasonType));
  }
  // Only meaningful alongside a week; the route drops it otherwise.
  if (year !== undefined) params.set("year", String(year));
  return fetchJson(`${BASE}/scoreboard?${params}`);
}

/**
 * One league's slate over a span of local days — the Scores screen's only
 * scoreboard request.
 *
 * The caller asks for five days to answer for three: ESPN reads `dates=` on
 * the Eastern clock, and the two-day margin absorbs the ET-to-local offset
 * for every time zone.
 */
export async function getScoreboardDays(
  league: League,
  start: Date,
  end: Date
): Promise<Scoreboard> {
  const params = new URLSearchParams({
    league,
    start: dayId(start),
    end: dayId(end),
  });
  return fetchJson(`${BASE}/scoreboard?${params}`);
}

/**
 * One league's games on ESPN's own days, by `dates=` token — the Scores
 * screen's live poll, between whole-window refreshes (`@/lib/live-days`).
 */
export async function getScoreboardDates(
  league: League,
  tokens: readonly string[]
): Promise<{ league: League; games: Game[] }> {
  const params = new URLSearchParams({ league, dates: tokens.join(",") });
  return fetchJson(`${BASE}/scoreboard?${params}`);
}

/**
 * One game's detail. Event ids are per-league — a summary fetched from the
 * wrong league's base URL 404s — so the league rides the request.
 */
export async function getGameDetail(
  league: League,
  gameId: string
): Promise<GameDetail> {
  return fetchJson(`${BASE}/game/${gameId}?league=${league}`);
}

/**
 * One matchup's series — the previous meetings and the tally they add up to.
 *
 * Its own request, not part of the page's, because it is a season-by-season
 * walk: ESPN has no head-to-head resource, so the bill is two requests per
 * season and it is only worth paying when the tab is actually opened.
 */
export async function getHeadToHead(
  league: League,
  gameId: string
): Promise<HeadToHead> {
  return fetchJson(`${BASE}/game/${gameId}/head-to-head?league=${league}`);
}

/**
 * One team's trophy case — every season back to the floor, derived from the
 * games it played. Requested on the tab's first open for the series' reason,
 * doubled: a dozen seasons is a dozen pairs of requests.
 */
export async function getTeamTrophies(
  league: League,
  teamId: string
): Promise<TrophyCase> {
  return fetchJson(`${BASE}/team/${teamId}/trophies?league=${league}`);
}

/**
 * A team's own stories, newest first (iOS E25, docs/news.md N9). Requested
 * when the News tab first opens — most visits never do.
 */
export async function getTeamNews(league: League, teamId: string): Promise<NewsStory[]> {
  return fetchJson(`${BASE}/team/${teamId}/news?league=${league}`);
}

/**
 * Several teams' own stories as one list (E26): each story once, newest
 * first — the News tab's For you, and a conference's members. Some feeds
 * failing makes a thinner list; all of them failing rejects.
 */
export async function getTeamsNews(teams: TeamRef[]): Promise<NewsStory[]> {
  if (teams.length === 0) return [];
  const results = await Promise.allSettled(
    teams.map((ref) => getTeamNews(ref.league, ref.teamId))
  );
  const feeds = results
    .filter((result) => result.status === "fulfilled")
    .map((result) => result.value);
  if (feeds.length === 0) throw new Error("No team feed answered");
  return forYou(feeds);
}

/** For you asks each followed team's own feed; capped so a long follow list
 *  doesn't open the page onto forty requests (iOS `forYouCap`). */
export const FOR_YOU_CAP = 20;

/** A player's stories (E26), newest first. Requested when the player
 *  page's News tab first opens. */
export async function getPlayerNews(league: League, athleteId: string): Promise<NewsStory[]> {
  return fetchJson(`${BASE}/player/${athleteId}/news?league=${league}`);
}

/** A league's stories for the News tab (E26), newest first, previews last. */
export async function getLeagueNews(league: League): Promise<NewsStory[]> {
  return fetchJson(`${BASE}/news?league=${league}`);
}

/** For you's sections (2026-09-27), iOS `NewsFeedStore.ForYouPage`. */
export interface ForYouPage {
  /** The newest real stories across the leagues — recency, not popularity,
   *  which ESPN doesn't publish. */
  trending: NewsStory[];
  /** Each followed team's own stories, by follow key; a team whose feed
   *  failed or came back empty isn't here. */
  teams: Record<string, NewsStory[]>;
  /** Every league's stories, newest first, previews last. */
  latest: NewsStory[];
}

/** Trending's size: the featured story and four under it. */
const TRENDING_SIZE = 5;
/** Latest is full-width photo cards; past this it's a scroll nobody
 *  finishes (iOS `latestCap`). */
const LATEST_CAP = 30;

/**
 * For you: every league at once (Trending and Latest) beside each followed
 * team's own feed. Rejects only when all of it failed.
 */
export async function getForYouPage(keys: readonly string[]): Promise<ForYouPage> {
  const follows = [...keys]
    .sort()
    .map((key) => ({ key, ref: parseFollowKey(key) }))
    .filter((entry): entry is { key: string; ref: TeamRef } => entry.ref !== undefined)
    .slice(0, FOR_YOU_CAP);
  const [leagues, ...teamResults] = await Promise.allSettled([
    getAllLeaguesNews(),
    ...follows.map((entry) => getTeamNews(entry.ref.league, entry.ref.teamId)),
  ]);
  const teams: Record<string, NewsStory[]> = {};
  let answered = 0;
  teamResults.forEach((result, index) => {
    if (result.status !== "fulfilled") return;
    answered += 1;
    const stories = result.value as NewsStory[];
    if (stories.length > 0) teams[follows[index].key] = stories;
  });
  if (leagues.status === "rejected" && answered === 0) {
    throw new Error("No news loaded");
  }
  const latest = leagues.status === "fulfilled" ? (leagues.value as NewsStory[]) : [];
  return {
    trending: latest.filter((story) => story.kind !== "preview").slice(0, TRENDING_SIZE),
    teams,
    latest: latest.slice(0, LATEST_CAP),
  };
}

/**
 * Every league's page as one (E26), for For you's Trending and Latest: each story
 * once, newest first, previews last. Some leagues failing makes a thinner
 * list; all of them failing rejects.
 */
export async function getAllLeaguesNews(): Promise<NewsStory[]> {
  const results = await Promise.allSettled(LEAGUES.map((league) => getLeagueNews(league)));
  const pages = results
    .filter((result) => result.status === "fulfilled")
    .map((result) => (result as PromiseFulfilledResult<NewsStory[]>).value);
  if (pages.length === 0) throw new Error("No league news loaded");
  return toppedUp([], pages);
}

/**
 * One season of a player's games. `season` is ESPN's own year (the ending
 * year for basketball and hockey); undefined asks for ESPN's current one.
 * Requested when the Games tab first opens — most visits never do.
 */
export async function getPlayerGameLog(
  league: League,
  athleteId: string,
  season?: number
): Promise<PlayerGameLog> {
  const params = new URLSearchParams({ league });
  if (season !== undefined) params.set("season", String(season));
  return fetchJson(`${BASE}/player/${athleteId}/gamelog?${params}`);
}
