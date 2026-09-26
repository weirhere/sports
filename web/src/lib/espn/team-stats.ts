// A team's season numbers and its statistical leaders — the web twin of iOS
// `TeamSeasonStats`, `TeamLeader` (StatSideShared/Models/TeamStats.swift) and
// `TeamStatsMapper` (StatSideShared/Networking/TeamStatsClient.swift).
//
// **Two hosts, both chosen.** The stats come from `site.web.api.espn.com`,
// because the same path on `site.api.espn.com` 403s by User-Agent (found
// 2026-09-24, the player stats' reason). The leaders come from the core API,
// the only place ESPN publishes them per team; it links each athlete as a
// `$ref` rather than naming them, so a leader arrives as an id and the
// provider resolves it.
//
// ESPN's category and stat names are carried through, never named here (the
// box score's rule). The registries below only pick which few lead the
// Overview; the Stats tab prints them all.

import {
  leagueSpec,
  seasonLabel,
  seasonYearFromEspn,
  type League,
} from "@/lib/leagues";

// --- Domain -------------------------------------------------------------

export interface TeamStat {
  /** ESPN's stable key: "totalPointsPerGame", "avgPoints". */
  name: string;
  /** Short enough for a tile: "TP/G", "PPG", "GAA". */
  label: string;
  /** "Total Points Per Game". */
  fullName: string;
  value: string;
  /** "17th" — football's opponent block ranks the defence; nothing else
   *  ships one. */
  rank?: string;
}

export interface TeamStatCategory {
  /** "passing", "offensive". */
  id: string;
  title: string;
  stats: TeamStat[];
}

export interface TeamSeasonStats {
  /** What season the numbers are — see `teamStatsSeasonLabel`. */
  seasonLabel?: string;
  categories: TeamStatCategory[];
  /** Football only: the same categories, for everyone who played this team. */
  opponent: TeamStatCategory[];
}

export const EMPTY_TEAM_STATS: TeamSeasonStats = {
  categories: [],
  opponent: [],
};

/** One of a team's leaders as the core API names them — by id only. */
export interface TeamLeader {
  /** ESPN's category key: "passingLeader", "pointsPerGame". */
  category: string;
  /** "Passing", "Points Per Game". */
  title: string;
  athleteId: string;
  /** "47/74, 566 YDS, 5 TD, 1 INT" or "33.5". */
  value: string;
}

/** A leader with a person attached, ready for a row. */
export interface ResolvedTeamLeader extends TeamLeader {
  name: string;
  headshotUrl?: string;
  /**
   * Whether the team's current roster named this leader, or the core
   * athlete record had to. It used to decide whether the row linked — the
   * player page was built from the roster, so a leader traded away had no
   * page — and no longer does: the page reads ESPN's athlete record now.
   */
  onRoster: boolean;
}

export interface TeamLeaders {
  leaders: ResolvedTeamLeader[];
  /** "2025-26" when the leaders fell back a season — see `teamLeaders`. */
  seasonLabel?: string;
}

export const EMPTY_TEAM_LEADERS: TeamLeaders = { leaders: [] };

// --- Registries ---------------------------------------------------------
//
// Straight copies of iOS `TeamSeasonStats.headlineNames(for:)` and
// `TeamLeader.categories(for:)`. Keyed by sport rather than read off
// `leagueSpec`, because they are a product decision per sport, and the two
// football leagues share one.

/**
 * Which of ESPN's stats lead a team's season. Scoring, then how, then the
 * one number that most often decides games in that sport.
 */
export function headlineNames(league: League): string[] {
  switch (league) {
    case "cfb":
    case "nfl":
      return [
        "totalPointsPerGame",
        "yardsPerGame",
        "thirdDownConvPct",
        "turnOverDifferential",
      ];
    case "nba":
      return ["avgPoints", "avgRebounds", "avgAssists", "fieldGoalPct"];
    case "nhl":
      return ["goals", "avgGoalsAgainst", "savePct", "faceoffPercent"];
  }
}

/**
 * Which categories a team's leaders card shows, per league, in order.
 * Football's `*Leader` categories carry a whole stat line rather than one
 * number, which is what a leader row wants.
 */
export function leaderCategories(league: League): string[] {
  switch (league) {
    case "cfb":
    case "nfl":
      return [
        "passingLeader",
        "rushingLeader",
        "receivingLeader",
        "totalTackles",
        "sacks",
        "interceptions",
      ];
    case "nba":
      return [
        "pointsPerGame",
        "reboundsPerGame",
        "assistsPerGame",
        "stealsPerGame",
        "blocksPerGame",
      ];
    case "nhl":
      return ["points", "goals", "assists", "wins", "savePct"];
  }
}

/** "Passing Leader" reads as a heading about a heading; the row needs the stat. */
export function leaderTitle(displayName: string): string {
  return displayName.endsWith(" Leader")
    ? displayName.slice(0, -" Leader".length)
    : displayName;
}

/** A stat by ESPN's name, first match — `receiving` repeats
 *  `receivingYards`, and several categories repeat `totalPoints`. */
export function findTeamStat(
  stats: TeamSeasonStats,
  name: string
): TeamStat | undefined {
  for (const category of stats.categories) {
    const stat = category.stats.find((entry) => entry.name === name);
    if (stat) return stat;
  }
  return undefined;
}

/** The Overview card's numbers, in the league's order, skipping any ESPN
 *  didn't send. */
export function teamStatHeadlines(
  stats: TeamSeasonStats,
  league: League
): TeamStat[] {
  return headlineNames(league)
    .map((name) => findTeamStat(stats, name))
    .filter((stat): stat is TeamStat => stat !== undefined);
}

// --- URLs ---------------------------------------------------------------

export function teamStatsUrl(league: League, teamId: string): string {
  const { sportSegment, pathSegment } = leagueSpec(league);
  return (
    `https://site.web.api.espn.com/apis/site/v2/sports/` +
    `${sportSegment}/${pathSegment}/teams/${teamId}/statistics`
  );
}

function coreSeasonBase(league: League, espnSeason: number): string {
  const { sportSegment, pathSegment } = leagueSpec(league);
  return (
    `https://sports.core.api.espn.com/v2/sports/${sportSegment}/leagues/` +
    `${pathSegment}/seasons/${espnSeason}`
  );
}

/** The regular season's leaders for ESPN season `espnSeason` (ESPN's
 *  spelling — the NBA's 2026-27 is 2027). A season with none is a 404. */
export function teamLeadersUrl(
  league: League,
  teamId: string,
  espnSeason: number
): string {
  return `${coreSeasonBase(league, espnSeason)}/types/2/teams/${teamId}/leaders`;
}

/** One athlete's core record — a name and a headshot for a leader the
 *  roster can't place. */
export function coreAthleteUrl(
  league: League,
  athleteId: string,
  espnSeason: number
): string {
  return `${coreSeasonBase(league, espnSeason)}/athletes/${athleteId}`;
}

// --- ESPN shapes --------------------------------------------------------
// Every field optional: the API is undocumented, and a missing field
// degrades the card, never the page.

export interface EspnTeamStatsResponse {
  season?: { year?: number; type?: number };
  results?: {
    stats?: { categories?: EspnTeamStatsCategory[] };
    opponent?: EspnTeamStatsCategory[];
  };
}

export interface EspnTeamStatsCategory {
  name?: string;
  displayName?: string;
  stats?: EspnTeamStat[];
}

export interface EspnTeamStat {
  name?: string;
  displayName?: string;
  shortDisplayName?: string;
  abbreviation?: string;
  displayValue?: string;
  rankDisplayValue?: string;
}

export interface EspnTeamLeadersResponse {
  categories?: {
    name?: string;
    displayName?: string;
    leaders?: {
      displayValue?: string;
      athlete?: { $ref?: string };
    }[];
  }[];
}

export interface EspnCoreAthlete {
  displayName?: string;
  fullName?: string;
  headshot?: { href?: string };
}

// --- Mapping ------------------------------------------------------------

/**
 * The payload as the page's season numbers, or empty for numbers not worth
 * showing — which the Overview hides and the Stats tab calls "TBA".
 */
export function transformTeamStats(
  data: EspnTeamStatsResponse,
  league: League
): TeamSeasonStats {
  const own = transformCategories(data.results?.stats?.categories);
  const opponent = transformCategories(data.results?.opponent);
  const label = teamStatsSeasonLabel(data.season, league, gamesPlayed(own));
  // A preseason answer with no real season behind it — see below.
  if (label === undefined) return EMPTY_TEAM_STATS;
  return { seasonLabel: label, categories: own, opponent };
}

/**
 * Which season these numbers are, or undefined for numbers not worth
 * showing.
 *
 * ESPN's own label can't be trusted across a rollover (verified
 * 2026-09-24): in September the NBA and NHL answer with a season named
 * "2026-27 Preseason" whose numbers are all of **last** season — 82 games
 * played. So a preseason answer with a full season's games (20 or more) is
 * labelled as the season it actually is, and one without — a real
 * preseason, a handful of exhibition games — is not shown at all. Printing
 * "2026-27" over last season's 82 games would be a false statement with
 * ESPN's label as its cover story.
 */
export function teamStatsSeasonLabel(
  season: EspnTeamStatsResponse["season"],
  league: League,
  gamesPlayed: number | undefined
): string | undefined {
  const year = season?.year;
  if (year === undefined) return undefined;
  const appYear = seasonYearFromEspn(league, year);
  if (season?.type !== 1) return seasonLabel(league, appYear);
  if (gamesPlayed === undefined || gamesPlayed < 20) return undefined;
  return seasonLabel(league, appYear - 1);
}

const GAMES_PLAYED_NAMES = ["gamesPlayed", "games", "teamGamesPlayed"];

function gamesPlayed(categories: TeamStatCategory[]): number | undefined {
  for (const name of GAMES_PLAYED_NAMES) {
    for (const category of categories) {
      const stat = category.stats.find((entry) => entry.name === name);
      // ESPN's `displayValue` carries thousands separators elsewhere
      // ("1,094"); a count of games never reaches one.
      const value = stat ? Number(stat.value) : Number.NaN;
      if (Number.isInteger(value)) return value;
    }
  }
  return undefined;
}

function transformCategories(
  categories: EspnTeamStatsCategory[] | undefined
): TeamStatCategory[] {
  const result: TeamStatCategory[] = [];
  for (const category of categories ?? []) {
    if (!category.name) continue;
    const seen = new Set<string>();
    const stats: TeamStat[] = [];
    for (const stat of category.stats ?? []) {
      // ESPN repeats a stat inside one category (`receivingYards` twice) —
      // once is the fact.
      if (!stat.name || stat.displayValue === undefined || seen.has(stat.name)) {
        continue;
      }
      seen.add(stat.name);
      const short =
        stat.shortDisplayName && stat.shortDisplayName.length <= 6
          ? stat.shortDisplayName
          : undefined;
      stats.push({
        name: stat.name,
        label: short ?? stat.abbreviation ?? stat.name,
        fullName: stat.displayName ?? stat.abbreviation ?? stat.name,
        value: stat.displayValue,
        rank: stat.rankDisplayValue ? stat.rankDisplayValue : undefined,
      });
    }
    if (stats.length === 0) continue;
    result.push({
      id: category.name,
      title: category.displayName ?? category.name,
      stats,
    });
  }
  return result;
}

/** The league's registry, in its order, read out of the core payload. */
export function transformTeamLeaders(
  data: EspnTeamLeadersResponse,
  league: League
): TeamLeader[] {
  const byName = new Map<string, NonNullable<EspnTeamLeadersResponse["categories"]>[number]>();
  for (const category of data.categories ?? []) {
    if (category.name && !byName.has(category.name)) {
      byName.set(category.name, category);
    }
  }
  const leaders: TeamLeader[] = [];
  for (const name of leaderCategories(league)) {
    const category = byName.get(name);
    const top = category?.leaders?.[0];
    const ref = top?.athlete?.$ref;
    const athleteId = ref ? athleteIdFromRef(ref) : undefined;
    if (!athleteId || top?.displayValue === undefined) continue;
    leaders.push({
      category: name,
      title: leaderTitle(category?.displayName ?? name),
      athleteId,
      value: top.displayValue,
    });
  }
  return leaders;
}

/** ".../seasons/2026/athletes/3139477?lang=en" → "3139477". */
export function athleteIdFromRef(ref: string): string | undefined {
  const match = /\/athletes\/(\d+)/.exec(ref);
  return match?.[1];
}

/**
 * Football's leaders carry a whole line — "47/74, 566 YDS, 5 TD, 1 INT" —
 * which reads under the name, where there is room for it. A single number
 * ("33.5") stands on the right in the row's emphasis.
 */
export function leaderValueIsStatLine(leader: TeamLeader): boolean {
  return leader.value.includes(",");
}
