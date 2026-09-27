// A team's stories and one story's text, fetched server-side — the web twin
// of iOS `NewsClient` (docs/news.md, N4 and N9). The game page's story needs
// neither: it arrives inside the summary the page already fetches.

import type { League } from "@/lib/leagues";
import type { NewsStory } from "@/lib/news";
import {
  newsStory,
  storyUrl,
  teamFeed,
  teamNewsUrl,
  type EspnNewsFeed,
  type EspnNewsHeadlines,
} from "./news";
import { EspnApiError } from "./provider";

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
