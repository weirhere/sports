// A team's stories and one story's text, fetched server-side — the web twin
// of iOS `NewsClient` (docs/news.md, N4 and N9). The game page's story needs
// neither: it arrives inside the summary the page already fetches.

import type { League } from "@/lib/leagues";
import type { NewsStory } from "@/lib/news";
import {
  isFlooded,
  leagueFeed,
  leagueNewsUrl,
  newsStory,
  storyUrl,
  teamFeed,
  teamNewsUrl,
  toppedUp,
  type EspnNewsFeed,
  type EspnNewsHeadlines,
} from "./news";
import { EspnApiError, rankings } from "./provider";

// A feed moves through a game day; a story, once written, barely does.
const REVALIDATE = { feed: 300, story: 3600 } as const;

async function fetchJson<T>(url: string, revalidate: number): Promise<T> {
  const res = await fetch(url, { next: { revalidate } });
  if (!res.ok) throw new EspnApiError(res.status, url);
  return res.json() as Promise<T>;
}

/** The stories about `teamId`, newest first. Throws when the request
 *  failed, so the tab can say so rather than that there's nothing to read. */
export async function teamNews(league: League, teamId: string): Promise<NewsStory[]> {
  const feed = await fetchJson<EspnNewsFeed>(teamNewsUrl(league, teamId), REVALIDATE.feed);
  return teamFeed(feed, teamId, league);
}

/** A league's feed for the News tab (E26), previews last. Throws when the
 *  request failed. */
export async function leagueNews(league: League): Promise<NewsStory[]> {
  const data = await fetchJson<EspnNewsFeed>(leagueNewsUrl(league), REVALIDATE.feed);
  const feed = leagueFeed(data, league);
  if (!isFlooded(feed)) return feed;
  // College football's feed can be nothing but AP's previews for the next
  // slate — all 50 items on 2026-09-27, every ESPN filter parameter
  // ignored — so a flooded page is topped up with the AP Top 10's own
  // stories. No poll (the pro leagues), or one that won't load, keeps the
  // feed as it came.
  const polls = await rankings(league).catch(() => []);
  const poll = polls.find((entry) => entry.type === "ap") ?? polls[0];
  if (!poll) return feed;
  const teamIds = [...poll.ranks]
    .sort((a, b) => a.rank - b.rank)
    .slice(0, TOP_UP_COUNT)
    .map((entry) => entry.team.id);
  const results = await Promise.allSettled(teamIds.map((id) => teamNews(league, id)));
  const teamFeeds = results
    .filter((result) => result.status === "fulfilled")
    .map((result) => result.value);
  return toppedUp(feed, teamFeeds);
}

/** How many of the poll's teams top up a flooded page (iOS `topUpCount`). */
const TOP_UP_COUNT = 10;

/** One story with its text, or undefined for an id that isn't a story the
 *  app shows (video, tickets) or has no text. Throws on a failed request. */
export async function newsStoryById(
  league: League,
  storyId: string
): Promise<NewsStory | undefined> {
  const data = await fetchJson<EspnNewsHeadlines>(storyUrl(storyId), REVALIDATE.story);
  const article = data.headlines?.[0];
  const story = article ? newsStory(article, league) : undefined;
  return story?.body ? story : undefined;
}
