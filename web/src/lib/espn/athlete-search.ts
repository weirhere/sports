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
