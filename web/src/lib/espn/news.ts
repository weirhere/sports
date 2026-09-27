// ESPN's news shapes and URLs — the web twin of iOS `NewsClient` and
// `NewsMapper` (StatSideShared/Networking/NewsClient.swift).
//
// One DTO across three sources: the summary's `article`, a `/news` feed's
// `articles[]`, and the content API's `headlines[]`. Each carries a subset —
// the feed has no `story`, no `source` and no `gameId` — so every field is
// optional. `images`, `video` and the web links are deliberately unread: the
// reader is text-only (N8) and never sends anyone to espn.com (N4).
//
// **Hosts.** The team feed reads `site.web.api.espn.com`: on `site.api` the
// path 403s a browser or empty User-Agent (probed 2026-09-27), and a server
// fetch's UA is neither a phone's nor guaranteed. A story's text comes from
// `content.core.api.espn.com`, which answers any UA and serves every story
// by id — a team feed's and the summary's recaps alike.

import type { League } from "@/lib/leagues";
import {
  attribution,
  decodeEntities,
  isFocused,
  storyBlocks,
  storyKind,
  type NewsStory,
  type StoryTeamTag,
} from "@/lib/news";

export interface EspnNewsCategory {
  type?: string;
  description?: string;
  teamId?: number | string;
  eventId?: number | string;
}

export interface EspnNewsArticle {
  id?: number | string;
  type?: string;
  headline?: string;
  description?: string;
  byline?: string;
  source?: string;
  published?: string;
  story?: string;
  gameId?: number | string;
  categories?: EspnNewsCategory[];
}

/** `/news?team=`: headlines only. */
export interface EspnNewsFeed {
  articles?: EspnNewsArticle[];
}

/** The content API's single story. */
export interface EspnNewsHeadlines {
  headlines?: EspnNewsArticle[];
}

const SPECS: Record<League, string> = {
  cfb: "football/college-football",
  nfl: "football/nfl",
  nba: "basketball/nba",
  nhl: "hockey/nhl",
};

export function teamNewsUrl(league: League, teamId: string): string {
  return `https://site.web.api.espn.com/apis/site/v2/sports/${SPECS[league]}/news?team=${teamId}&limit=25`;
}

/** A league's own feed, for the News tab's league pages (E26). */
export function leagueNewsUrl(league: League): string {
  return `https://site.web.api.espn.com/apis/site/v2/sports/${SPECS[league]}/news?limit=50`;
}

export function storyUrl(storyId: string): string {
  return `https://content.core.api.espn.com/v1/sports/news/${storyId}`;
}

function idString(value: number | string | undefined): string | undefined {
  if (value === undefined || value === null) return undefined;
  const text = String(value).trim();
  return /^\d+$/.test(text) ? text : undefined;
}

/**
 * A story the app will show, or undefined: an unshown type (N10) or no
 * headline. The text is kept where it rode along — the summary's recap and
 * the content API's story; a feed item has none.
 */
export function newsStory(dto: EspnNewsArticle, league: League): NewsStory | undefined {
  const kind = storyKind(dto.type);
  const id = idString(dto.id);
  const headline = dto.headline?.trim();
  if (!kind || !id || !headline) return undefined;

  const categories = dto.categories ?? [];
  const seen = new Set<string>();
  const teams: StoryTeamTag[] = [];
  for (const category of categories) {
    if (category.type !== "team") continue;
    const teamId = idString(category.teamId);
    if (!teamId || seen.has(teamId)) continue;
    seen.add(teamId);
    teams.push({ id: teamId, name: category.description ?? "" });
  }
  const eventId = idString(categories.find((category) => category.type === "event")?.eventId);
  const body = dto.story ? storyBlocks(dto.story) : [];
  // AP deks open with the same stray dash the dateline carries.
  const dek = dto.description?.trim().replace(/^[—–\s]+/, "");

  return {
    id,
    kind,
    league,
    headline: decodeEntities(headline),
    dek: dek ? decodeEntities(dek) : undefined,
    attribution: attribution(dto.byline, dto.source),
    published: dto.published,
    gameId: idString(dto.gameId) ?? eventId,
    teams,
    body: body.length > 0 ? body : undefined,
  };
}

/** The team's feed after both filters (N9, N10), newest first. */
export function teamFeed(dto: EspnNewsFeed, teamId: string, league: League): NewsStory[] {
  return (dto.articles ?? [])
    .map((article) => newsStory(article, league))
    .filter((story): story is NewsStory => story !== undefined && isFocused(story, teamId))
    .map((story) => ({ ...story, body: undefined }))
    .sort((a, b) => (b.published ?? "").localeCompare(a.published ?? ""));
}

function newestFirst(a: NewsStory, b: NewsStory): number {
  return (b.published ?? "").localeCompare(a.published ?? "");
}

/**
 * A league's feed (E26): the types the app shows, newest first, and
 * **previews last**. ESPN's college-football feed floods with AP's previews
 * for the next slate — on 2026-09-27 all 50 items were previews published
 * within four minutes — and a page that leads with 50 of them buries every
 * other story. Demoted rather than dropped: on a quiet day they're what
 * there is.
 */
export function leagueFeed(dto: EspnNewsFeed, league: League): NewsStory[] {
  return (dto.articles ?? [])
    .map((article) => newsStory(article, league))
    .filter((story): story is NewsStory => story !== undefined)
    .map((story) => ({ ...story, body: undefined }))
    .sort((a, b) => {
      const aPreview = a.kind === "preview";
      const bPreview = b.kind === "preview";
      if (aPreview !== bPreview) return aPreview ? 1 : -1;
      return newestFirst(a, b);
    });
}

/**
 * For you (E26): every followed team's own stories in one list, each story
 * once — a recap tags both teams, and a user may follow both — newest
 * first. Follows carry no order of their own, so time is the only honest
 * ranking.
 */
export function forYou(feeds: NewsStory[][]): NewsStory[] {
  const seen = new Set<string>();
  return feeds
    .flat()
    .filter((story) => (seen.has(story.id) ? false : (seen.add(story.id), true)))
    .sort(newestFirst);
}
