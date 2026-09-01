// The Scores sectioning engine — a faithful port of the iOS
// `ScoreboardStore.sections(...)` pipeline (sports/Stores/ScoreboardStore.swift).
// Pure functions over the domain `Game`: the view layer feeds it the slate,
// the follow sets, and the active filters; it hands back ordered sections.
//
// The product rule that shapes everything here: sections are COMPLETE, never
// deduplicated. A game appears in every section whose promise it satisfies —
// Following, Top 25, and both conferences of a cross-conference matchup.

import type { Game, GameStatus } from "./types";
import { conferenceLogoUrl, conferenceName, tier, tierRank } from "./conferences";

export type ScoresGrouping = "date" | "conference";

/**
 * The slate filter's persisted spelling — `"top25"` or `"conference-8"`,
 * matching the iOS `ScoreFilter.token` encoding. `null` means all games.
 */
export type ScoreFilterToken = string;

export const FOLLOWING_SECTION_ID = "following";
export const TOP25_SECTION_ID = "top25";
export const DAY_SECTION_PREFIX = "day-";
export const TBD_SECTION_ID = "day-tbd";

export type SectionKind = "following" | "top25" | "day" | "conference";

export interface GameSection {
  /** Stable across refetches — expansion state keys off this. */
  id: string;
  title: string;
  kind: SectionKind;
  games: Game[];
  /** Conference sections only: the mark for the header. */
  logoUrl?: string;
  /**
   * ESPN's numeric group id — set only on conference sections with a known
   * conference. It's what the header's name link navigates with; the
   * "Other" bucket has none.
   */
  conferenceId?: number;
}

export interface BuildSectionsOptions {
  grouping: ScoresGrouping;
  /** Followed team ids (ESPN numeric strings). */
  followedTeamIds: ReadonlySet<string> | string[];
  /** Followed conference ids (ESPN numeric group ids). */
  followedConferenceIds: ReadonlySet<number> | number[];
  liveOnly?: boolean;
  scoreFilter?: ScoreFilterToken | null;
  /**
   * Preseason has no poll yet; pass false to suppress the Top 25 section
   * when the ranks source is known-empty. Defaults to true (rank data on
   * the games themselves still gates the section).
   */
  top25RanksAvailable?: boolean;
}

const LIVE_STATUSES: ReadonlySet<GameStatus> = new Set([
  "in_progress",
  "halftime",
  "end_period",
]);

export function isLiveStatus(status: GameStatus): boolean {
  return LIVE_STATUSES.has(status);
}

function involvesRankedTeam(game: Game): boolean {
  return (
    game.homeTeam.ranking !== undefined || game.awayTeam.ranking !== undefined
  );
}

function numericConferenceId(raw: string | undefined): number | undefined {
  if (raw === undefined) return undefined;
  const id = Number(raw);
  return Number.isFinite(id) ? id : undefined;
}

/**
 * The conference ids a game can be claimed by — sides whose conference the
 * registry knows. An FCS visitor (unknown conference) contributes nothing,
 * so its game stays in the FBS host's section only.
 */
function knownConferenceIds(game: Game): number[] {
  const ids = new Set<number>();
  for (const side of [game.homeTeam, game.awayTeam]) {
    const id = numericConferenceId(side.team.conferenceId);
    if (id !== undefined && tier(id) !== "other") ids.add(id);
  }
  return [...ids];
}

/** The sheet/empty-state name for a filter token ("SEC", "Top 25"). */
export function scoreFilterLabel(token: ScoreFilterToken): string {
  if (token === "top25") return "Top 25";
  const id = parseConferenceToken(token);
  return id !== undefined ? conferenceName(id) : token;
}

/**
 * The header chip's label — long conference names get their common short
 * forms so the chip row still fits (the iOS `chipLabel` table).
 */
export function scoreFilterChipLabel(token: ScoreFilterToken): string {
  const id = parseConferenceToken(token);
  switch (id) {
    case 12:
      return "C-USA";
    case 17:
      return "MWC";
    case 18:
      return "Indep.";
    default:
      return scoreFilterLabel(token);
  }
}

export function conferenceFilterToken(id: number): ScoreFilterToken {
  return `conference-${id}`;
}

export function parseConferenceToken(
  token: ScoreFilterToken | null | undefined
): number | undefined {
  if (!token || !token.startsWith("conference-")) return undefined;
  const id = Number(token.slice("conference-".length));
  return Number.isInteger(id) ? id : undefined;
}

/** True when `token` is a spelling this module understands. */
export function isValidScoreFilterToken(token: string): boolean {
  return token === "top25" || parseConferenceToken(token) !== undefined;
}

/**
 * The same claim rules the sections use: any ranked participant for Top 25,
 * either side's conference for a conference filter — so an FCS visitor's
 * game stays visible under its FBS host's conference.
 */
function matchesFilter(game: Game, token: ScoreFilterToken): boolean {
  if (token === "top25") return involvesRankedTeam(game);
  const id = parseConferenceToken(token);
  if (id === undefined) return true;
  return (
    numericConferenceId(game.homeTeam.team.conferenceId) === id ||
    numericConferenceId(game.awayTeam.team.conferenceId) === id
  );
}

/** Kickoff order, ties broken by id; games without a parseable date sink. */
function chronological(games: Game[]): Game[] {
  return [...games].sort((a, b) => {
    const at = Date.parse(a.scheduledAt);
    const bt = Date.parse(b.scheduledAt);
    const aValid = Number.isFinite(at);
    const bValid = Number.isFinite(bt);
    if (aValid && bValid && at !== bt) return at - bt;
    if (aValid !== bValid) return aValid ? -1 : 1;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });
}

function isFollowed(
  game: Game,
  teamIds: ReadonlySet<string>,
  conferenceIds: ReadonlySet<number>
): boolean {
  for (const side of [game.homeTeam, game.awayTeam]) {
    if (teamIds.has(side.team.id)) return true;
    const confId = numericConferenceId(side.team.conferenceId);
    if (confId !== undefined && conferenceIds.has(confId)) return true;
  }
  return false;
}

/** Local calendar-day key ("2026-08-29") — stable expansion ids. */
export function localDayKey(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function dayTitle(date: Date): string {
  // "Saturday, Aug 29" — the iOS `.weekday(.wide).month(.abbreviated).day()`.
  return date.toLocaleDateString("en-US", {
    weekday: "long",
    month: "short",
    day: "numeric",
  });
}

/**
 * One section per LOCAL calendar day, chronological; games with no parseable
 * kickoff land in a trailing "TBD" section. Expects `visible` already
 * chronological — the buckets preserve it.
 */
function daySections(visible: Game[]): GameSection[] {
  const byDay = new Map<string, { date: Date; games: Game[] }>();
  const undated: Game[] = [];
  for (const game of visible) {
    const time = Date.parse(game.scheduledAt);
    if (!Number.isFinite(time)) {
      undated.push(game);
      continue;
    }
    const date = new Date(time);
    const key = localDayKey(date);
    const bucket = byDay.get(key);
    if (bucket) {
      bucket.games.push(game);
    } else {
      byDay.set(key, { date, games: [game] });
    }
  }
  const sections: GameSection[] = [...byDay.entries()]
    .sort(([a], [b]) => (a < b ? -1 : 1))
    .map(([key, bucket]) => ({
      id: `${DAY_SECTION_PREFIX}${key}`,
      title: dayTitle(bucket.date),
      kind: "day" as const,
      games: bucket.games,
    }));
  if (undated.length > 0) {
    sections.push({
      id: TBD_SECTION_ID,
      title: "TBD",
      kind: "day",
      games: undated,
    });
  }
  return sections;
}

/**
 * Top 25 → conference sections, the stack below Following in conference
 * grouping. A cross-conference game lands in BOTH conferences' sections;
 * "Other" is a last resort for games no known conference can claim.
 */
function rankedAndConferenceSections(
  visible: Game[],
  followedTeamIds: ReadonlySet<string>,
  followedConferenceIds: ReadonlySet<number>,
  top25RanksAvailable: boolean
): GameSection[] {
  const sections: GameSection[] = [];

  if (top25RanksAvailable) {
    const ranked = visible.filter(involvesRankedTeam);
    if (ranked.length > 0) {
      sections.push({
        id: TOP25_SECTION_ID,
        title: "Top 25",
        kind: "top25",
        games: ranked,
      });
    }
  }

  const byConference = new Map<number | null, Game[]>();
  for (const game of visible) {
    const known = knownConferenceIds(game);
    if (known.length === 0) {
      const other = byConference.get(null);
      if (other) other.push(game);
      else byConference.set(null, [game]);
    } else {
      for (const id of known) {
        const bucket = byConference.get(id);
        if (bucket) bucket.push(game);
        else byConference.set(id, [game]);
      }
    }
  }

  // A followed team's conference floats to the top — as does an explicitly
  // followed conference; then P4 → G5 → Independents → Other.
  const floated = new Set<number>(followedConferenceIds);
  for (const game of visible) {
    for (const side of [game.homeTeam, game.awayTeam]) {
      if (!followedTeamIds.has(side.team.id)) continue;
      const confId = numericConferenceId(side.team.conferenceId);
      if (confId !== undefined) floated.add(confId);
    }
  }

  const orderedIds = [...byConference.keys()].sort((lhs, rhs) => {
    const lf = lhs !== null && floated.has(lhs);
    const rf = rhs !== null && floated.has(rhs);
    if (lf !== rf) return lf ? -1 : 1;
    const lt = tierRank(tier(lhs));
    const rt = tierRank(tier(rhs));
    if (lt !== rt) return lt - rt;
    return conferenceName(lhs) < conferenceName(rhs) ? -1 : 1;
  });

  for (const id of orderedIds) {
    const name = conferenceName(id);
    sections.push({
      id: `conf-${name}`,
      title: name,
      kind: "conference",
      games: byConference.get(id) ?? [],
      logoUrl: conferenceLogoUrl(id),
      conferenceId: id ?? undefined,
    });
  }
  return sections;
}

/**
 * The whole pipeline: filter → sort once → Following pinned first in BOTH
 * groupings → the grouping's own stack. "Complete" means complete within
 * the active filters; empty sections are never emitted.
 */
export function buildSections(
  games: Game[],
  options: BuildSectionsOptions
): GameSection[] {
  const followedTeamIds =
    options.followedTeamIds instanceof Set
      ? options.followedTeamIds
      : new Set(options.followedTeamIds);
  const followedConferenceIds =
    options.followedConferenceIds instanceof Set
      ? options.followedConferenceIds
      : new Set(options.followedConferenceIds);

  let visible = options.liveOnly
    ? games.filter((game) => isLiveStatus(game.status))
    : games;
  const filter = options.scoreFilter ?? null;
  if (filter !== null) {
    visible = visible.filter((game) => matchesFilter(game, filter));
  }
  // One sort up front: every bucketing step below preserves order, so each
  // section inherits chronology from here instead of re-sorting its slice.
  visible = chronological(visible);

  const sections: GameSection[] = [];

  const followed = visible.filter((game) =>
    isFollowed(game, followedTeamIds, followedConferenceIds)
  );
  if (followed.length > 0) {
    sections.push({
      id: FOLLOWING_SECTION_ID,
      title: "Following",
      kind: "following",
      games: followed,
    });
  }

  if (options.grouping === "conference") {
    sections.push(
      ...rankedAndConferenceSections(
        visible,
        followedTeamIds,
        followedConferenceIds,
        options.top25RanksAvailable ?? true
      )
    );
  } else {
    sections.push(...daySections(visible));
  }
  return sections;
}
