// League-qualified identities — a port of the iOS app's `FollowKey`,
// `TeamRef` and `ConferenceID` (StatSideShared/Models/FollowKey.swift,
// Team.swift).
//
// ESPN ids collide across leagues and the collisions are not exotic: id 5 is
// UAB *and* the Browns, id 2 is Auburn *and* the Bills, id 26 is UCLA *and*
// the Seahawks — 20 of the NFL's 32 team ids have a college twin. Group id 8
// is the SEC here and the AFC there.
//
// So nothing in the app stores or routes on a bare id. A team is a
// `TeamRef`, a conference is a `ConferenceRef`, and a follow is the string
// spelling of one.

import { LEAGUES, type League, isLeague } from "./leagues";

export interface TeamRef {
  league: League;
  teamId: string;
}

export interface ConferenceRef {
  league: League;
  /** ESPN group id. */
  id: number;
}

/** The stored/URL spelling of a followed team — `"cfb:130"`, `"nfl:26"`. */
export function followKey(ref: TeamRef): string {
  return `${ref.league}:${ref.teamId}`;
}

/**
 * Parses a stored key.
 *
 * A bare id predates the league axis and reads as college football — the
 * same fallback the namespacing migration uses, kept here so a key that
 * somehow escaped it still resolves.
 *
 * Empty components fail rather than resolving to a plausible-looking wrong
 * answer: `"nfl:"` must not parse as a *college* team named "nfl", and
 * `":26"` must not parse as college team 26.
 */
export function parseFollowKey(raw: string): TeamRef | undefined {
  if (raw.length === 0) return undefined;
  const separator = raw.indexOf(":");
  if (separator === -1) return { league: "cfb", teamId: raw };
  const league = raw.slice(0, separator);
  const teamId = raw.slice(separator + 1);
  if (!isLeague(league) || teamId.length === 0) return undefined;
  return { league, teamId };
}

/** The stored/URL spelling of a conference — `"cfb:8"`, `"nfl:8"`. */
export function conferenceToken(ref: ConferenceRef): string {
  return `${ref.league}:${ref.id}`;
}

export function parseConferenceToken(
  raw: string
): ConferenceRef | undefined {
  const separator = raw.indexOf(":");
  if (separator === -1) {
    // Pre-axis tokens were bare group ids, which were always college
    // football's — the only league the app had.
    const id = Number(raw);
    return Number.isInteger(id) ? { league: "cfb", id } : undefined;
  }
  const league = raw.slice(0, separator);
  const id = Number(raw.slice(separator + 1));
  if (!isLeague(league) || !Number.isInteger(id)) return undefined;
  return { league, id };
}

export function sameTeam(a: TeamRef | undefined, b: TeamRef | undefined): boolean {
  return a != null && b != null && a.league === b.league && a.teamId === b.teamId;
}

export function sameConference(
  a: ConferenceRef | undefined,
  b: ConferenceRef | undefined
): boolean {
  return a != null && b != null && a.league === b.league && a.id === b.id;
}

/** The stored keys that parse, as refs. */
export function parseFollowKeys(raw: readonly string[]): TeamRef[] {
  return raw
    .map(parseFollowKey)
    .filter((ref): ref is TeamRef => ref !== undefined);
}

/** Followed team ids within one league, unqualified — what a per-league
 * fetcher (a schedule, a scoreboard) actually wants. */
export function followedTeamIds(
  raw: readonly string[],
  league: League
): Set<string> {
  return new Set(
    parseFollowKeys(raw)
      .filter((ref) => ref.league === league)
      .map((ref) => ref.teamId)
  );
}

/**
 * The leagues this follow set actually touches, in league order.
 *
 * Every caller that fans out per league asks this first, so a
 * college-football-only user never pays for an NFL request — the
 * polite-guest rule survives the second league.
 */
export function followedLeagues(raw: readonly string[]): League[] {
  const touched = new Set(parseFollowKeys(raw).map((ref) => ref.league));
  return LEAGUES.filter((league) => touched.has(league));
}

/**
 * The league you follow most, or `undefined` on a tie or an empty set.
 *
 * This is search's ranking tiebreak. It replaced an app-wide "current
 * league" scope on iOS (2026-09-05): with every league on the page at once,
 * "the league you follow most" is a better signal than "the tab you last
 * tapped".
 */
export function preferredLeague(raw: readonly string[]): League | undefined {
  const counts = new Map<League, number>();
  for (const ref of parseFollowKeys(raw)) {
    counts.set(ref.league, (counts.get(ref.league) ?? 0) + 1);
  }
  let best: League | undefined;
  let bestCount = 0;
  let tied = false;
  for (const league of LEAGUES) {
    const count = counts.get(league) ?? 0;
    if (count === 0) continue;
    if (count > bestCount) {
      best = league;
      bestCount = count;
      tied = false;
    } else if (count === bestCount) {
      tied = true;
    }
  }
  return tied ? undefined : best;
}
