// The team page's season numbers and leaders, fetched server-side — the web
// twin of iOS `TeamStatsClient` and `TeamStatsModel`.
//
// Same contract as the iOS client: nothing here throws. Any failure answers
// empty, and the Overview cards hide rather than apologise. That is also
// what lets the page hand these to the client as promises it never has to
// catch.

import {
  espnSeason,
  seasonLabel,
  seasonYearContaining,
  seasonYearFromEspn,
  type League,
} from "@/lib/leagues";
import { headshotThumbnail } from "@/lib/logos";
import type { RosterPlayer } from "@/lib/types";
import { teamRoster } from "./provider";
import {
  EMPTY_TEAM_LEADERS,
  EMPTY_TEAM_STATS,
  coreAthleteUrl,
  teamLeadersUrl,
  teamStatsUrl,
  transformTeamLeaders,
  transformTeamStats,
  type EspnCoreAthlete,
  type EspnTeamLeadersResponse,
  type EspnTeamStatsResponse,
  type ResolvedTeamLeader,
  type TeamLeader,
  type TeamLeaders,
  type TeamSeasonStats,
} from "./team-stats";

// Season numbers move once a game day; an athlete's name never does.
const REVALIDATE = { stats: 3600, leaders: 3600, athlete: 86400 } as const;

/** The body, or undefined for anything but a 200 that parses. */
async function fetchOptional<T>(url: string, revalidate: number): Promise<T | undefined> {
  try {
    const res = await fetch(url, { next: { revalidate } });
    if (!res.ok) return undefined;
    return (await res.json()) as T;
  } catch {
    return undefined;
  }
}

export async function teamSeasonStats(
  league: League,
  teamId: string
): Promise<TeamSeasonStats> {
  const data = await fetchOptional<EspnTeamStatsResponse>(
    teamStatsUrl(league, teamId),
    REVALIDATE.stats
  );
  return data ? transformTeamStats(data, league) : EMPTY_TEAM_STATS;
}

/**
 * The regular season's leaders, named.
 *
 * "Now" is the app-wide season clock, the one the player page's This season
 * card uses: in September an NBA team's now is 2026-27, which has no
 * leaders yet (a 404), so the request falls back one season and the card
 * says whose season it shows.
 *
 * Leaders arrive as bare athlete ids, resolved first against the team's own
 * roster — the request the page already makes, which Next dedupes — then,
 * only for the few the roster can't place (a player traded since), against
 * the core athlete record. A leader nothing can name is dropped rather than
 * shown as a number with no person.
 */
export async function teamLeaders(
  league: League,
  teamId: string,
  now: Date = new Date()
): Promise<TeamLeaders> {
  const season = espnSeason(league, seasonYearContaining(now));
  let entries: TeamLeader[] = [];
  let answered: number | undefined;
  for (const year of [season, season - 1]) {
    const data = await fetchOptional<EspnTeamLeadersResponse>(
      teamLeadersUrl(league, teamId, year),
      REVALIDATE.leaders
    );
    entries = data ? transformTeamLeaders(data, league) : [];
    if (entries.length > 0) {
      answered = year;
      break;
    }
  }
  if (answered === undefined) return EMPTY_TEAM_LEADERS;

  let players: RosterPlayer[] = [];
  try {
    const roster = await teamRoster(league, teamId);
    players = roster.groups.flatMap((group) => group.players);
  } catch {
    // No roster: every leader goes to the athlete record instead.
  }
  const byId = new Map(players.map((player) => [player.id, player]));

  const answeredSeason = answered;
  const resolved = await Promise.all(
    entries.map(async (entry): Promise<ResolvedTeamLeader | undefined> => {
      const player = byId.get(entry.athleteId);
      if (player) {
        return {
          ...entry,
          name: player.name,
          headshotUrl: thumbnail(player.headshotUrl),
          onRoster: true,
        };
      }
      const athlete = await fetchOptional<EspnCoreAthlete>(
        coreAthleteUrl(league, entry.athleteId, answeredSeason),
        REVALIDATE.athlete
      );
      const name = athlete?.displayName ?? athlete?.fullName;
      if (!name) return undefined;
      return {
        ...entry,
        name,
        headshotUrl: thumbnail(athlete?.headshot?.href),
        onRoster: false,
      };
    })
  );

  return {
    leaders: resolved.filter(
      (leader): leader is ResolvedTeamLeader => leader !== undefined
    ),
    seasonLabel:
      answered === season
        ? undefined
        : seasonLabel(league, seasonYearFromEspn(league, answered)),
  };
}

function thumbnail(url: string | undefined): string | undefined {
  if (!url) return undefined;
  return headshotThumbnail(url) ?? url;
}
