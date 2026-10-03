// ESPN's own search, which is how athletes reach the search box — the web
// twin of iOS `AthleteSearchClient` (StatSideShared/Networking/
// AthleteSearchClient.swift, 2026-09-21).
//
// Its own module rather than a method in `provider.ts`, for the reason iOS
// gives its own client: every provider method is league-scoped, and this
// endpoint is league-agnostic — one request answers for all four leagues at
// once. Server-side only, like the rest of `lib/espn`.
//
// **Why this exists at all.** Search's other corpora are already loaded (the
// team directory, the conference registry, the slate), which is why typing
// costs nothing. Athletes have no such corpus: the roster endpoint is per
// team, so four leagues would be ~228 fetches for an index that goes stale
// weekly. This is the one request that does it.

import { LEAGUES, leagueSpec, type League } from "@/lib/leagues";
import type { SearchAthlete } from "@/lib/types";
import { attribution, decodeEntities, storyKind, type NewsStory } from "@/lib/news";
import { storyImage } from "./news";
import { athleteSearchUrl } from "./endpoints";
import { EspnApiError } from "./provider";
import type { EspnSearchContent, EspnSearchResponse } from "./types";

/** ESPN indexes every sport; asking for more than the page shows only buys
 *  more of the ones we filter out (iOS `AthleteSearchStore.limit`). */
export const ATHLETE_SEARCH_LIMIT = 10;

/**
 * Pulls `3895074` out of `s:70~l:90~a:3895074`.
 *
 * Tilde-separated `key:value` pairs, parsed rather than pattern-matched so
 * an extra or reordered segment can't shift the answer.
 */
export function athleteIdFromUid(uid: string | null | undefined): string | undefined {
  if (!uid) return undefined;
  const segment = uid.split("~").find((part) => part.startsWith("a:"));
  const id = segment?.slice(2);
  return id ? id : undefined;
}

function leagueForSlug(slug: string | undefined): League | undefined {
  if (!slug) return undefined;
  return LEAGUES.find((league) => leagueSpec(league).pathSegment === slug);
}

/**
 * One search hit, as far as it goes. Undefined for anyone outside the four
 * leagues — ESPN indexes every sport it covers, so a common surname returns
 * soccer and baseball players this app has no page for, and a row that
 * opens an empty page is worse than no row.
 */
export function transformSearchAthlete(
  content: EspnSearchContent
): SearchAthlete | undefined {
  const athleteId = athleteIdFromUid(content.uid);
  const name = content.displayName;
  const league = leagueForSlug(content.defaultLeagueSlug);
  if (!athleteId || !name || !league) return undefined;
  return {
    athleteId,
    league,
    name,
    teamName: content.subtitle ? content.subtitle : undefined,
    headshotUrl: content.image?.default ? content.image.default : undefined,
  };
}

/** Only the `player` group; an unknown group type is skipped, not guessed. */
export function transformAthleteSearch(
  data: EspnSearchResponse
): SearchAthlete[] {
  return (data.results ?? [])
    .filter((group) => group.type === "player")
    .flatMap((group) => group.contents ?? [])
    .flatMap((content) => {
      const athlete = transformSearchAthlete(content);
      return athlete ? [athlete] : [];
    });
}

/**
 * Athletes matching `query` in the four leagues this app covers. An empty
 * or whitespace query costs no request.
 *
 * Cached for a minute: long enough that the same name typed twice by two
 * visitors is one upstream call, short enough that a signing shows up the
 * same day.
 */
export async function searchAthletes(query: string): Promise<SearchAthlete[]> {
  const trimmed = query.trim();
  if (trimmed.length === 0) return [];
  const url = athleteSearchUrl(trimmed, ATHLETE_SEARCH_LIMIT);
  const res = await fetch(url, { next: { revalidate: 60 } });
  if (!res.ok) throw new EspnApiError(res.status, url);
  return transformAthleteSearch((await res.json()) as EspnSearchResponse);
}

function parseLink(link: string | null | undefined): URL | undefined {
  if (!link) return undefined;
  try {
    return new URL(link);
  } catch {
    return undefined;
  }
}

/** `https://www.espn.com/college-football/story/…` → `cfb`. AP's recaps and
 *  previews link through ESPN's older paths (`/ncf/recap?gameId=…`), where
 *  college football is `ncf`. */
export function leagueForStoryLink(link: string | null | undefined): League | undefined {
  const segment = parseLink(link)?.pathname.split("/")[1];
  return segment === "ncf" ? "cfb" : leagueForSlug(segment);
}

/** A recap's or preview's game, from that older path's query. */
export function gameIdForStoryLink(link: string | null | undefined): string | undefined {
  return parseLink(link)?.searchParams.get("gameId") || undefined;
}

/** Feeds say `HeadlineNews`, search says `headlinenews`. */
const SEARCH_TYPES: Record<string, string> = {
  recap: "Recap",
  preview: "Preview",
  headlinenews: "HeadlineNews",
  story: "Story",
};

/**
 * A search hit as a story (E26), or undefined: an unshown type, no headline,
 * or a league the app doesn't cover. Search sends no teams, no dek and no
 * text, so the reader fetches the story by id.
 */
export function transformSearchStory(content: EspnSearchContent): NewsStory | undefined {
  const kind = storyKind(SEARCH_TYPES[(content.type ?? "").toLowerCase()]);
  const id = content.id && /^\d+$/.test(content.id) ? content.id : undefined;
  const headline = content.displayName?.trim();
  const league = leagueForStoryLink(content.link?.web);
  if (!kind || !id || !headline || !league) return undefined;
  return {
    id,
    kind,
    league,
    headline: decodeEntities(headline),
    // The field is a byline or a wire, and nothing says which.
    attribution: attribution(undefined, content.byline ?? undefined),
    published: content.date ?? undefined,
    gameId: gameIdForStoryLink(content.link?.web),
    teams: [],
    imageUrl: storyImage(content.images ?? undefined),
  };
}

/** The `article` group, in ESPN's order for the query. Clips and replays
 *  are video, which N10 keeps out of every list. */
export function transformStorySearch(data: EspnSearchResponse): NewsStory[] {
  const seen = new Set<string>();
  return (data.results ?? [])
    .filter((group) => group.type === "article")
    .flatMap((group) => group.contents ?? [])
    .flatMap((content) => {
      const story = transformSearchStory(content);
      if (!story || seen.has(story.id)) return [];
      seen.add(story.id);
      return [story];
    });
}

/**
 * The people and the stories one query found (E26). The response carries
 * both, so Search's News scope costs no request of its own.
 */
export async function searchAll(
  query: string
): Promise<{ athletes: SearchAthlete[]; stories: NewsStory[] }> {
  const trimmed = query.trim();
  if (trimmed.length === 0) return { athletes: [], stories: [] };
  const url = athleteSearchUrl(trimmed, ATHLETE_SEARCH_LIMIT);
  const res = await fetch(url, { next: { revalidate: 60 } });
  if (!res.ok) throw new EspnApiError(res.status, url);
  const data = (await res.json()) as EspnSearchResponse;
  return { athletes: transformAthleteSearch(data), stories: transformStorySearch(data) };
}
