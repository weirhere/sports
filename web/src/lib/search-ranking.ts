// Search matching + ranking — a faithful port of the iOS app's
// `SearchResults` (sports/Features/Search/SearchResults.swift). Pure and
// deterministic: same inputs, same output, no clock, no network — the whole
// corpus is already loaded, so results are instant.

import type { ConferenceTeams, Game, Team } from "@/lib/types";

/** A registry conference reference — search's conference corpus rows. */
export interface ConferenceRef {
  id: number;
  name: string;
}

/** Case- and diacritic-insensitive: "jose" finds San José State. */
export function fold(s: string): string {
  return s
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function foldedQuery(query: string): string {
  return fold(query.trim());
}

/** "San José State Spartans" — the iOS `displayName` field, rebuilt. */
function displayName(team: Team): string {
  return [team.school, team.name].filter(Boolean).join(" ");
}

/**
 * Lower tier = better match. 0: exact abbreviation ("uga"), 1: a word in
 * any field starts with the query, 2: substring anywhere. Null: no match.
 */
export function teamMatchTier(query: string, team: Team): number | null {
  const folded = foldedQuery(query);
  if (folded.length === 0) return null;
  if (team.abbreviation && fold(team.abbreviation) === folded) return 0;
  const fields = [team.school, team.name, team.abbreviation, displayName(team)]
    .filter((field) => field.length > 0)
    .map(fold);
  if (
    fields.some((field) =>
      field.split(" ").some((word) => word.startsWith(folded))
    )
  ) {
    return 1;
  }
  if (fields.some((field) => field.includes(folded))) return 2;
  return null;
}

/**
 * The ranked team slice, shared by app-wide search and the Teams/onboarding
 * inline filters. Sort: followed first → match tier → school alphabetical.
 * Pass no follow set for a purely match-ranked list (the inline filters do —
 * their rows toggle follows, and a followed-first boost would reorder the
 * list under the user's finger).
 */
export function searchTeams(
  query: string,
  conferences: ConferenceTeams[],
  followedIds: ReadonlySet<string> = new Set()
): Team[] {
  const folded = foldedQuery(query);
  if (folded.length === 0) return [];

  const seen = new Set<string>();
  return conferences
    .flatMap((conference) => conference.teams)
    .flatMap((team) => {
      const tier = teamMatchTier(folded, team);
      if (tier === null || seen.has(team.id)) return [];
      seen.add(team.id);
      return [{ team, followed: followedIds.has(team.id), tier }];
    })
    .sort((lhs, rhs) => {
      if (lhs.followed !== rhs.followed) return lhs.followed ? -1 : 1;
      if (lhs.tier !== rhs.tier) return lhs.tier - rhs.tier;
      return lhs.team.school.localeCompare(rhs.team.school, "en", {
        sensitivity: "base",
      });
    })
    .map((entry) => entry.team);
}

/** Conferences: prefix matches before substring, alphabetical within. */
export function searchConferences(
  query: string,
  conferences: ConferenceRef[]
): ConferenceRef[] {
  const folded = foldedQuery(query);
  if (folded.length === 0) return [];
  return conferences
    .filter((conference) => fold(conference.name).includes(folded))
    .sort((lhs, rhs) => {
      const lp = fold(lhs.name).startsWith(folded);
      const rp = fold(rhs.name).startsWith(folded);
      if (lp !== rp) return lp ? -1 : 1;
      return lhs.name.localeCompare(rhs.name, "en", { sensitivity: "base" });
    });
}

/**
 * Games matched by either side's tier or the matchup name as a substring,
 * in kickoff order (ids as the stable tiebreak).
 */
export function searchGames(query: string, games: Game[]): Game[] {
  const folded = foldedQuery(query);
  if (folded.length === 0) return [];
  return games
    .filter((game) => {
      if (teamMatchTier(folded, game.awayTeam.team) !== null) return true;
      if (teamMatchTier(folded, game.homeTeam.team) !== null) return true;
      const matchupName = `${displayName(game.awayTeam.team)} at ${displayName(
        game.homeTeam.team
      )}`;
      return fold(matchupName).includes(folded);
    })
    .sort((lhs, rhs) => {
      const lt = Date.parse(lhs.scheduledAt);
      const rt = Date.parse(rhs.scheduledAt);
      const lValid = !Number.isNaN(lt);
      const rValid = !Number.isNaN(rt);
      // Dated games in kickoff order, undated last, ids as the tiebreak.
      if (lValid && rValid && lt !== rt) return lt - rt;
      if (lValid !== rValid) return lValid ? -1 : 1;
      return lhs.id < rhs.id ? -1 : lhs.id > rhs.id ? 1 : 0;
    });
}
