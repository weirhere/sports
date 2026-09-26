// One athlete: profile, season-by-season stats and a season's game log —
// the web twin of iOS `AthleteProfileClient` and `PlayerStatsClient`
// (StatSideShared/Networking/).
//
// **The host is `site.web.api.espn.com`, deliberately.** `site.api.espn.com`
// — the host the rest of `src/lib/espn/` reads — puts its athlete and stats
// paths behind an Akamai rule that 403s by User-Agent, and has no
// `/athletes/{id}` at all. The same data answers 200 from `site.web.api`'s
// `common/v3` tree in all four leagues (probed 2026-09-24, re-probed for
// this port 2026-09-25).
//
// Kept out of `transformers.ts` and `provider.ts` on purpose: the three
// payloads share nothing with the scoreboard family, and every function
// here answers a degraded value rather than throwing — a player page that
// shows a name and a club is the state it started from, and an error over
// it would be louder than the thing it apologises for.

import { leagueSpec, type League } from "@/lib/leagues";
import type { AthleteProfile } from "@/lib/player-profile";
import type {
  PlayerGameLog,
  PlayerGameLogEntry,
  PlayerGameLogSection,
  PlayerStats,
  PlayerStatsCategory,
  PlayerSeasonLine,
} from "@/lib/player-stats";

// --- URLs ---------------------------------------------------------------

function athleteBase(league: League, athleteId: string): string {
  const { sportSegment, pathSegment } = leagueSpec(league);
  return (
    `https://site.web.api.espn.com/apis/common/v3/sports/` +
    `${sportSegment}/${pathSegment}/athletes/${athleteId}`
  );
}

export function athleteUrl(league: League, athleteId: string): string {
  return athleteBase(league, athleteId);
}

/** Every season the player has a line for, plus ESPN's career totals. */
export function athleteStatsUrl(league: League, athleteId: string): string {
  return `${athleteBase(league, athleteId)}/stats`;
}

/**
 * One season's games. `season` is ESPN's year — the ending year for
 * basketball and hockey; undefined asks for ESPN's current one.
 */
export function athleteGameLogUrl(
  league: League,
  athleteId: string,
  season?: number
): string {
  const base = `${athleteBase(league, athleteId)}/gamelog`;
  return season === undefined ? base : `${base}?season=${season}`;
}

// --- ESPN shapes --------------------------------------------------------
//
// Every field optional, per the root CLAUDE.md: a missing field degrades
// the page, never breaks it. Ids arrive as strings in one payload and
// numbers in the next, so they are typed as either.

type EspnId = string | number;

interface EspnLogo {
  href?: string;
  rel?: string[];
}

export interface EspnAthleteResponse {
  athlete?: {
    displayName?: string;
    fullName?: string;
    /** Present for the pro leagues; absent for college football, whose
     *  roster metric is the class year. */
    age?: number;
    jersey?: string;
    displayHeight?: string;
    displayWeight?: string;
    position?: { abbreviation?: string; displayName?: string };
    headshot?: { href?: string };
    status?: { name?: string; type?: string };
    team?: {
      id?: EspnId;
      displayName?: string;
      location?: string;
      logos?: EspnLogo[];
    };
  };
}

export interface EspnAthleteStatsResponse {
  teams?: Record<
    string,
    { id?: EspnId; displayName?: string; abbreviation?: string }
  >;
  categories?: {
    name?: string;
    displayName?: string;
    labels?: string[];
    names?: string[];
    displayNames?: string[];
    statistics?: {
      teamId?: EspnId;
      season?: { year?: number; displayName?: string };
      stats?: string[];
      position?: string;
    }[];
    totals?: string[];
  }[];
}

interface EspnGameLogSide {
  id?: EspnId;
  abbreviation?: string;
  displayName?: string | null;
  logo?: string;
}

export interface EspnAthleteGameLogResponse {
  labels?: string[];
  names?: string[];
  filters?: { name?: string; value?: string; options?: { value?: string }[] }[];
  events?: Record<
    string,
    {
      week?: number;
      atVs?: string;
      gameDate?: string;
      homeTeamScore?: string;
      awayTeamScore?: string;
      gameResult?: string;
      eventNote?: string;
      opponent?: EspnGameLogSide;
      /** The player's own side — id, abbreviation and mark. */
      team?: EspnGameLogSide;
    }
  >;
  seasonTypes?: {
    displayName?: string;
    categories?: {
      /** "event" for a run of games; "total" for ESPN's own subtotal row,
       *  which is not a game. */
      type?: string;
      events?: { eventId?: string; stats?: string[] }[];
    }[];
  }[];
}

// --- Transformers -------------------------------------------------------

function idString(id: EspnId | undefined): string | undefined {
  return id === undefined || id === "" ? undefined : String(id);
}

function nonEmpty(value: string | null | undefined): string | undefined {
  return value === undefined || value === null || value === "" ? undefined : value;
}

/**
 * The athlete's own profile. Undefined when the payload carries no athlete
 * at all, which is the caller's cue to lean on the roster alone.
 */
export function transformAthleteProfile(
  data: EspnAthleteResponse
): AthleteProfile | undefined {
  const athlete = data.athlete;
  if (!athlete) return undefined;
  const team = athlete.team;
  const logos = team?.logos ?? [];
  const logo =
    logos.find((entry) => entry.rel?.includes("default"))?.href ?? logos[0]?.href;
  // ESPN says "Active" for everyone who isn't hurt, which is not a fact
  // worth a row of its own — iOS `AthleteProfileClient`'s rule.
  const status =
    athlete.status?.type && athlete.status.type !== "active"
      ? nonEmpty(athlete.status.name)
      : undefined;

  return {
    name: nonEmpty(athlete.displayName) ?? nonEmpty(athlete.fullName),
    age: typeof athlete.age === "number" ? athlete.age : undefined,
    jersey: nonEmpty(athlete.jersey),
    position: nonEmpty(athlete.position?.abbreviation),
    positionName: nonEmpty(athlete.position?.displayName),
    height: nonEmpty(athlete.displayHeight),
    weight: nonEmpty(athlete.displayWeight),
    headshotUrl: nonEmpty(athlete.headshot?.href),
    injuryStatus: status,
    teamId: idString(team?.id),
    // The app's one team name (2026-09-21): `displayName ?? location`.
    teamName: nonEmpty(team?.displayName) ?? nonEmpty(team?.location),
    teamLogoUrl: nonEmpty(logo),
  };
}

export function transformAthleteStats(
  data: EspnAthleteStatsResponse
): PlayerStats {
  const clubs = new Map<string, { name?: string; abbreviation?: string }>();
  for (const team of Object.values(data.teams ?? {})) {
    const id = idString(team.id);
    if (id) {
      clubs.set(id, {
        name: nonEmpty(team.displayName),
        abbreviation: nonEmpty(team.abbreviation),
      });
    }
  }

  const categories: PlayerStatsCategory[] = [];
  for (const group of data.categories ?? []) {
    const labels = group.labels ?? [];
    if (!group.name || labels.length === 0) continue;

    const seasons: PlayerSeasonLine[] = [];
    for (const row of group.statistics ?? []) {
      const year = row.season?.year;
      // A row that doesn't match the header would put every number under
      // the wrong column — the box score's rule.
      if (year === undefined || !row.stats || row.stats.length !== labels.length) {
        continue;
      }
      const teamId = idString(row.teamId);
      const club = teamId ? clubs.get(teamId) : undefined;
      seasons.push({
        year,
        label: nonEmpty(row.season?.displayName) ?? String(year),
        teamId,
        teamName: club?.name,
        teamAbbreviation: club?.abbreviation,
        position: nonEmpty(row.position),
        values: row.stats,
      });
    }
    if (seasons.length === 0) continue;

    const career = group.totals ?? [];
    categories.push({
      id: group.name,
      title: nonEmpty(group.displayName) ?? group.name,
      labels,
      names: group.names ?? [],
      displayNames: group.displayNames ?? [],
      seasons,
      career: career.length === labels.length ? career : [],
    });
  }
  return { categories };
}

export function transformAthleteGameLog(
  data: EspnAthleteGameLogResponse
): PlayerGameLog {
  const labels = data.labels ?? [];
  const events = data.events ?? {};

  const sections: PlayerGameLogSection[] = [];
  for (const type of data.seasonTypes ?? []) {
    const entries: PlayerGameLogEntry[] = [];
    for (const category of type.categories ?? []) {
      if (category.type !== undefined && category.type !== "event") continue;
      for (const row of category.events ?? []) {
        if (!row.eventId || !row.stats || row.stats.length !== labels.length) {
          continue;
        }
        entries.push(logEntry(row.eventId, row.stats, events[row.eventId]));
      }
    }
    if (entries.length > 0) {
      sections.push({ title: nonEmpty(type.displayName) ?? "Games", entries });
    }
  }

  const seasonFilter = data.filters?.find((filter) => filter.name === "season");
  const toYear = (value: string | undefined) => {
    const year = Number(value);
    return value && Number.isInteger(year) ? year : undefined;
  };

  return {
    labels,
    names: data.names ?? [],
    sections,
    availableSeasons: (seasonFilter?.options ?? [])
      .map((option) => toYear(option.value))
      .filter((year): year is number => year !== undefined),
    season: toYear(seasonFilter?.value),
  };
}

function logEntry(
  eventId: string,
  values: string[],
  event: NonNullable<EspnAthleteGameLogResponse["events"]>[string] | undefined
): PlayerGameLogEntry {
  const isAway = event?.atVs === "@";
  const home = nonEmpty(event?.homeTeamScore);
  const away = nonEmpty(event?.awayTeamScore);
  return {
    eventId,
    date: nonEmpty(event?.gameDate),
    week: typeof event?.week === "number" ? event.week : undefined,
    isAway,
    opponentId: idString(event?.opponent?.id),
    opponentAbbreviation: nonEmpty(event?.opponent?.abbreviation),
    opponentName: nonEmpty(event?.opponent?.displayName),
    opponentLogoUrl: nonEmpty(event?.opponent?.logo),
    teamId: idString(event?.team?.id),
    result: nonEmpty(event?.gameResult),
    teamScore: isAway ? away : home,
    opponentScore: isAway ? home : away,
    note: nonEmpty(event?.eventNote),
    values,
  };
}

// --- Fetches ------------------------------------------------------------

// Cache lifetimes (seconds). A profile and a career move slowly; a game log
// gains a row a night at most. None of it is polled.
const REVALIDATE = { profile: 3600, stats: 3600, gameLog: 900 } as const;

/**
 * `null` for any failure — a non-2xx, a network error, a body that isn't
 * JSON. Every caller here degrades rather than throws, so a typed error
 * would only be caught and discarded one line later.
 */
async function fetchOrNull<T>(url: string, revalidate: number): Promise<T | null> {
  try {
    const res = await fetch(url, { next: { revalidate } });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

export async function athleteProfile(
  league: League,
  athleteId: string
): Promise<AthleteProfile | undefined> {
  const data = await fetchOrNull<EspnAthleteResponse>(
    athleteUrl(league, athleteId),
    REVALIDATE.profile
  );
  return data ? transformAthleteProfile(data) : undefined;
}

/** Empty categories on any failure — the Stats and Career tabs then show their empty states. */
export async function athleteStats(
  league: League,
  athleteId: string
): Promise<PlayerStats> {
  const data = await fetchOrNull<EspnAthleteStatsResponse>(
    athleteStatsUrl(league, athleteId),
    REVALIDATE.stats
  );
  return data ? transformAthleteStats(data) : { categories: [] };
}

/**
 * One season's game log. **Throws** where the others degrade: the Games
 * tab's route needs to tell "no games this season" from "ESPN didn't
 * answer", because only one of them is worth a Retry button.
 */
export async function athleteGameLog(
  league: League,
  athleteId: string,
  season?: number
): Promise<PlayerGameLog> {
  const url = athleteGameLogUrl(league, athleteId, season);
  const res = await fetch(url, { next: { revalidate: REVALIDATE.gameLog } });
  if (!res.ok) throw new Error(`ESPN game log ${res.status}: ${url}`);
  return transformAthleteGameLog((await res.json()) as EspnAthleteGameLogResponse);
}
