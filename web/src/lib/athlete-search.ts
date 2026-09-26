// Which of ESPN's athlete hits this app can open — the filter half of iOS
// `AthleteSearchStore.search(_:collegeTeamsInScope:)` (2026-09-21), plus the
// one thing the web needs that iOS does not: a team id.
//
// Pure: the athletes come from `/api/search/athletes`, the directory from
// `useTeamDirectory`, and nothing here fetches.

import type { ConferenceTeams, SearchAthlete, Team } from "./types";
import type { League } from "./leagues";
import { fold } from "./search-ranking";

/** A search hit the web can link: the athlete plus the club's team id. */
export interface LinkableAthlete extends SearchAthlete {
  teamId: string;
}

/** "Edmonton Oilers" — the string ESPN's search puts in `subtitle`. */
export function teamDisplayName(team: Pick<Team, "school" | "name">): string {
  return [team.school, team.name].filter(Boolean).join(" ");
}

function directoryKey(league: League, name: string): string {
  return `${league}\u0000${fold(name.trim())}`;
}

/**
 * The athletes a tap can open, each carrying its club's team id.
 *
 * **The directory is the arbiter, not a hardcoded division list.** ESPN's
 * `college-football` slug indexes Division II and III too, so a "McDavid"
 * query returns Mars Hill beside Harvard — Harvard is a real FCS page here
 * and Mars Hill is nothing. Search hands this FBS and FCS (the shared
 * directory plus `useFcsDirectory`) and nothing else, so matching the club
 * against it keeps exactly the players this app has a page for, and follows
 * the app the day it adds a division.
 *
 * **Deliberate divergence from iOS: the pro leagues are resolved too.** iOS
 * lets an NFL, NBA or NHL hit through unfiltered, because its player page
 * can be pushed from a name and fills itself from the athlete endpoint. The
 * web's player route is `/player/[league]/[teamId]/[athleteId]` — the team
 * id is in the URL because a cold load rebuilds the page from that team's
 * roster — and search serves the club only as text. So every hit resolves
 * its club through the directory by name, and one that can't (a free agent
 * with no `subtitle`, a league whose directory hasn't loaded) is dropped: a
 * row that opens nothing is worse than no row.
 */
export function linkableAthletes(
  athletes: readonly SearchAthlete[],
  conferences: readonly ConferenceTeams[]
): LinkableAthlete[] {
  const teams = new Map<string, Team>();
  for (const team of conferences.flatMap((conference) => conference.teams)) {
    const key = directoryKey(team.league, teamDisplayName(team));
    if (!teams.has(key)) teams.set(key, team);
  }

  const seen = new Set<string>();
  return athletes.flatMap((athlete) => {
    if (!athlete.teamName) return [];
    const team = teams.get(directoryKey(athlete.league, athlete.teamName));
    // Keyed per league: ESPN reuses athlete ids across them.
    const key = `${athlete.league}:${athlete.athleteId}`;
    if (!team || seen.has(key)) return [];
    seen.add(key);
    return [{ ...athlete, teamId: team.id }];
  });
}
