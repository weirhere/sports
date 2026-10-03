// A head coach's career — the web twin of iOS `Coach.swift` and
// `CoachMapper` (StatSideShared/, E27, 2026-09-27). Pure: the fetches live
// in `espn/coach.ts`, so every rule here is testable against a capture.
//
// **Head coaches only, one league per page.** ESPN lists exactly one coach
// per team-season in every league and has no staff endpoint, and its coach
// ids are per league with nothing joining them (Harbaugh is NFL `27`, and
// `college-football/coaches/27` 404s). Probed live 2026-09-27.

import { seasonLabel, seasonYearFromEspn, type League } from "@/lib/leagues";

export type CoachRecordKind = "total" | "regular" | "postseason";

const KIND_ORDER: CoachRecordKind[] = ["total", "regular", "postseason"];

export const RECORD_TITLES: Record<CoachRecordKind, string> = {
  total: "Career",
  regular: "Regular season",
  postseason: "Postseason",
};

export interface CoachRecord {
  kind: CoachRecordKind;
  wins: number;
  losses: number;
  ties: number;
  /** Hockey's overtime losses, which ESPN counts apart from `losses`. */
  overtimeLosses: number;
}

export interface CoachSeason {
  /** Our opening-year axis: an NBA "2026" arrives here as 2025. */
  year: number;
  teamId: string;
  /** The regular-season line. ESPN publishes no per-season postseason
   *  record (`types/3/.../record` 404s even for a playoff year). */
  record?: CoachRecord;
}

export interface CoachStint {
  teamId: string;
  /** Newest first. */
  seasons: CoachSeason[];
}

export interface CoachTeamLabel {
  name: string;
  abbreviation?: string;
  logoUrl?: string;
}

export interface CoachProfile {
  name: string;
  headshotUrl?: string;
  /** "1963-11-18", the calendar date only. College coaches carry none. */
  dateOfBirth?: string;
  birthPlace?: string;
  college?: string;
  /** The team the person record names now, for the hero's badge. */
  currentTeamId?: string;
  records: CoachRecord[];
  /** Newest first, zero-game seasons and duplicates removed. */
  seasons: CoachSeason[];
}

export interface CoachCareer {
  profile: CoachProfile;
  teams: Record<string, CoachTeamLabel>;
}

// --- ESPN shapes (core API) ---------------------------------------------

type EspnId = string | number;

export interface EspnRef {
  $ref?: string;
}

export interface EspnCoachPerson {
  id?: EspnId;
  firstName?: string;
  lastName?: string;
  dateOfBirth?: string;
  birthPlace?: { city?: string; state?: string; country?: string };
  college?: EspnRef;
  headshot?: { href?: string };
  team?: EspnRef;
  experience?: number;
  careerRecords?: EspnRef[];
  coachSeasons?: EspnRef[];
}

export interface EspnCoachRecord {
  id?: EspnId;
  name?: string;
  type?: string;
  stats?: { name?: string; value?: number }[];
}

export interface EspnCoachSeason {
  records?: { team?: EspnRef; record?: EspnRef }[];
}

// --- Mapping ------------------------------------------------------------

function nonEmpty(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

/** The team id out of a `…/seasons/2019/teams/99?lang=en` ref. */
export function teamIdInRef(ref: string | undefined): string | undefined {
  const match = ref?.match(/\/teams\/(\d+)/);
  return match?.[1];
}

/** `…/seasons/2016/coaches/7157?lang=en` → 2016, ESPN's year. */
export function seasonYearInRef(ref: string | undefined): number | undefined {
  const match = ref?.match(/\/seasons\/(\d{4})/);
  return match ? Number(match[1]) : undefined;
}

export function coachProfile(person: EspnCoachPerson): CoachProfile {
  const name = [person.firstName, person.lastName]
    .map(nonEmpty)
    .filter((part): part is string => part !== undefined)
    .join(" ");
  const place = [
    person.birthPlace?.city,
    person.birthPlace?.state ?? person.birthPlace?.country,
  ]
    .map(nonEmpty)
    .filter((part): part is string => part !== undefined)
    .join(", ");
  const dob = person.dateOfBirth?.slice(0, 10);
  return {
    name,
    headshotUrl: nonEmpty(person.headshot?.href),
    dateOfBirth: dob && /^\d{4}-\d{2}-\d{2}$/.test(dob) ? dob : undefined,
    birthPlace: place || undefined,
    currentTeamId: teamIdInRef(person.team?.$ref),
    records: [],
    seasons: [],
  };
}

/** Whole years on `now`, or undefined without a birth date. */
export function coachAge(dateOfBirth: string | undefined, now: Date = new Date()): number | undefined {
  if (!dateOfBirth) return undefined;
  const [y, m, d] = dateOfBirth.split("-").map(Number);
  let age = now.getUTCFullYear() - y;
  const month = now.getUTCMonth() + 1;
  if (month < m || (month === m && now.getUTCDate() < d)) age -= 1;
  return age;
}

/**
 * Which line this is, from ESPN's name ("Total", "Regular Season", "Post
 * Season") with the ref's id (0, 2, 3) behind it.
 *
 * Overtime losses come in three spellings: the NFL's payload says
 * `OTLosses`, and there they're already inside `losses`; the NHL's says
 * `otLosses` and `overtimeLosses`, outside `losses` (Tocchet's 2019-20:
 * "33-29-0-8"). So they're read for the NHL only.
 */
export function coachRecord(dto: EspnCoachRecord, league: League): CoachRecord | undefined {
  const label = (dto.type ?? dto.name ?? "").toLowerCase();
  const id = dto.id === undefined ? undefined : String(dto.id);
  let kind: CoachRecordKind;
  if (label.includes("post") || id === "3") kind = "postseason";
  else if (label.includes("regular") || id === "2") kind = "regular";
  else if (label.includes("total") || id === "0") kind = "total";
  else return undefined;

  const stats = new Map<string, number>();
  for (const stat of dto.stats ?? []) {
    if (stat.name && typeof stat.value === "number") {
      stats.set(stat.name, Math.round(stat.value));
    }
  }
  const wins = stats.get("wins");
  const losses = stats.get("losses");
  if (wins === undefined || losses === undefined) return undefined;
  const otl =
    stats.get("overtimeLosses") ?? stats.get("otLosses") ?? stats.get("OTLosses") ?? 0;
  return {
    kind,
    wins,
    losses,
    ties: stats.get("ties") ?? 0,
    overtimeLosses: league === "nhl" ? otl : 0,
  };
}

export function recordGames(record: CoachRecord): number {
  return record.wins + record.losses + record.ties + record.overtimeLosses;
}

/** "59-74", "8-8-1" with a tie, "1072-671-77-159" for hockey's old ties
 *  beside its overtime losses. A zero ties column is dropped. */
export function recordSummary(record: CoachRecord): string {
  const parts = [record.wins, record.losses];
  if (record.ties > 0) parts.push(record.ties);
  if (record.overtimeLosses > 0) parts.push(record.overtimeLosses);
  return parts.join("-");
}

/** ".541" — a tie counts half; undefined with no games, where ".000" would
 *  claim a record that doesn't exist. */
export function winPercentText(record: CoachRecord): string | undefined {
  const games = recordGames(record);
  if (games === 0) return undefined;
  const pct = (record.wins + record.ties / 2) / games;
  return pct.toFixed(3).replace(/^0\./, ".");
}

/**
 * Career lines in reading order, one per kind. College football ships Total
 * and Regular Season identical and no postseason, so a regular line equal to
 * the total says nothing twice and is dropped.
 */
export function careerRecords(records: CoachRecord[]): CoachRecord[] {
  const byKind = new Map<CoachRecordKind, CoachRecord>();
  for (const record of records) if (!byKind.has(record.kind)) byKind.set(record.kind, record);
  const total = byKind.get("total");
  const regular = byKind.get("regular");
  if (
    total &&
    regular &&
    !byKind.has("postseason") &&
    total.wins === regular.wins &&
    total.losses === regular.losses &&
    total.ties === regular.ties
  ) {
    byKind.delete("regular");
  }
  return KIND_ORDER.map((kind) => byKind.get(kind)).filter(
    (record): record is CoachRecord => record !== undefined && recordGames(record) > 0
  );
}

/** One row per team the season names; the record goes to it only when
 *  there's one team to give it to. */
export function coachSeasons(
  dto: EspnCoachSeason | null | undefined,
  espnYear: number,
  record: CoachRecord | undefined,
  league: League
): CoachSeason[] {
  const ids = [
    ...new Set(
      (dto?.records ?? [])
        .map((row) => teamIdInRef(row.team?.$ref))
        .filter((id): id is string => id !== undefined)
    ),
  ];
  return ids.map((teamId) => ({
    year: seasonYearFromEspn(league, espnYear),
    teamId,
    record: ids.length === 1 ? record : undefined,
  }));
}

export function seasonId(season: CoachSeason): string {
  return `${season.year}-${season.teamId}`;
}

/**
 * Newest first, duplicates gone, and no season the coach didn't coach.
 *
 * ESPN lists the season a coach left as a zero-game row at the old team —
 * Kalen DeBoer reads "2024 Washington 0-0" (twice) for the year DeBoer was at
 * Alabama. A season with *no* record is kept: the current one, before
 * kickoff, answers 404 and is still the job.
 */
export function cleanedSeasons(seasons: CoachSeason[]): CoachSeason[] {
  const seen = new Set<string>();
  return seasons
    .filter((season) => {
      if (season.record && recordGames(season.record) === 0) return false;
      const id = seasonId(season);
      if (seen.has(id)) return false;
      seen.add(id);
      return true;
    })
    .sort((a, b) => (a.year !== b.year ? b.year - a.year : a.teamId.localeCompare(b.teamId)));
}

/** Consecutive seasons at one team, newest first — "where they coached". */
export function coachStints(seasons: CoachSeason[]): CoachStint[] {
  const out: CoachStint[] = [];
  for (const season of seasons) {
    const last = out[out.length - 1];
    const earliest = last?.seasons[last.seasons.length - 1]?.year;
    if (last && last.teamId === season.teamId && earliest !== undefined && earliest - season.year === 1) {
      last.seasons.push(season);
    } else {
      out.push({ teamId: season.teamId, seasons: [season] });
    }
  }
  return out;
}

/** "2022–2026", or "2016" for a single season, on the league's axis. */
export function stintSpan(stint: CoachStint, league: League): string {
  const newest = stint.seasons[0]?.year;
  const oldest = stint.seasons[stint.seasons.length - 1]?.year;
  if (newest === undefined || oldest === undefined) return "";
  if (newest === oldest) return seasonLabel(league, newest);
  return `${seasonLabel(league, oldest)}–${seasonLabel(league, newest)}`;
}

/** The stint's regular seasons summed — the only arithmetic on a coach,
 *  since ESPN keeps no per-job total. */
export function stintRecord(stint: CoachStint): CoachRecord | undefined {
  const lines = stint.seasons
    .map((season) => season.record)
    .filter((record): record is CoachRecord => record !== undefined);
  if (lines.length === 0) return undefined;
  const sum = (pick: (r: CoachRecord) => number) => lines.reduce((n, r) => n + pick(r), 0);
  return {
    kind: "regular",
    wins: sum((r) => r.wins),
    losses: sum((r) => r.losses),
    ties: sum((r) => r.ties),
    overtimeLosses: sum((r) => r.overtimeLosses),
  };
}

/** "TB" for Todd Bowles: the first and last words, suffixes skipped. */
export function coachInitials(name: string): string {
  const words = name.split(/\s+/).filter((w) => w && !["Jr.", "Sr.", "II", "III", "IV"].includes(w));
  const letters = [words[0], words.length > 1 ? words[words.length - 1] : undefined]
    .map((w) => w?.[0])
    .filter(Boolean);
  return letters.join("").toUpperCase();
}
