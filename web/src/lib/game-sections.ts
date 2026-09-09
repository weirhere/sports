// The Scores sectioning engine — a faithful port of the iOS
// `ScoreboardStore.sections(...)` pipeline (sports/Stores/ScoreboardStore.swift).
// Pure functions over the domain `Game`: the view layer feeds it the slate,
// the follow sets, and the active filters; it hands back ordered sections.
//
// The product rule that shapes everything here: sections are COMPLETE, never
// deduplicated. A game appears in every section whose promise it satisfies —
// Following, Top 25, and both conferences of a cross-conference matchup.

import type { Game, GameStatus } from "./types";
import {
  conferenceLogoUrl,
  conferenceName,
  conferenceNameFor,
  tier,
  tierRank,
} from "./conferences";
import {
  conferenceToken,
  followKey,
  parseConferenceToken as parseRefToken,
  type ConferenceRef,
} from "./refs";

export type ScoresGrouping = "date" | "conference";

/**
 * The slate filter's persisted spelling — `"top25"` or
 * `"conference-cfb:8"`, matching the iOS `ScoreFilter.token` encoding.
 * `null` means all games.
 *
 * The conference half is league-qualified because group 8 is the SEC and
 * the AFC. A pre-axis `"conference-8"` still parses, as college football's.
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
   * The conference this section is — set only on conference sections with a
   * known conference. It's what the header's name link navigates with; the
   * "Other" bucket has none.
   */
  conference?: ConferenceRef;
}

export interface BuildSectionsOptions {
  grouping: ScoresGrouping;
  /**
   * Followed teams as league-qualified keys (`"cfb:130"`), never bare ids:
   * ESPN id 5 is UAB *and* the Browns, so a bare-id set would follow both.
   */
  followedTeamKeys: ReadonlySet<string> | string[];
  /**
   * Followed conferences as league-qualified tokens (`"cfb:8"`) — group 8
   * is the SEC here and the AFC there.
   */
  followedConferenceTokens: ReadonlySet<string> | string[];
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
    if (id !== undefined && tier(id, game.league) !== "other") ids.add(id);
  }
  return [...ids];
}

/** The sheet/empty-state name for a filter token ("SEC", "Top 25"). */
export function scoreFilterLabel(token: ScoreFilterToken): string {
  if (token === "top25") return "Top 25";
  const ref = parseConferenceToken(token);
  return ref !== undefined ? conferenceName(ref.id, ref.league) : token;
}

/**
 * The header chip's label — long conference names get their common short
 * forms so the chip row still fits (the iOS `chipLabel` table).
 */
export function scoreFilterChipLabel(token: ScoreFilterToken): string {
  const ref = parseConferenceToken(token);
  // College football's own long names; a pro league's are already short.
  switch (ref?.league === "cfb" ? ref.id : undefined) {
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

export function conferenceFilterToken(ref: ConferenceRef): ScoreFilterToken {
  return `conference-${ref.league}:${ref.id}`;
}

export function parseConferenceToken(
  token: ScoreFilterToken | null | undefined
): ConferenceRef | undefined {
  if (!token || !token.startsWith("conference-")) return undefined;
  return parseRefToken(token.slice("conference-".length));
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
  const ref = parseConferenceToken(token);
  if (ref === undefined) return true;
  // A filter can't speak for a league it isn't about: "SEC" is not a
  // question the NFL's slate can answer, so its games are hidden outright
  // rather than emptied into a section.
  if (game.league !== ref.league) return false;
  return (
    numericConferenceId(game.homeTeam.team.conferenceId) === ref.id ||
    numericConferenceId(game.awayTeam.team.conferenceId) === ref.id
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
  teamKeys: ReadonlySet<string>,
  conferenceTokens: ReadonlySet<string>
): boolean {
  for (const side of [game.homeTeam, game.awayTeam]) {
    if (teamKeys.has(followKey({ league: game.league, teamId: side.team.id }))) {
      return true;
    }
    const confId = numericConferenceId(side.team.conferenceId);
    if (
      confId !== undefined &&
      conferenceTokens.has(conferenceToken({ league: game.league, id: confId }))
    ) {
      return true;
    }
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
  followedTeamKeys: ReadonlySet<string>,
  followedConferenceTokens: ReadonlySet<string>,
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

  // Keyed by the league-qualified conference, never by the bare group id:
  // a mixed slate would otherwise merge the SEC's games into the AFC's.
  const byConference = new Map<
    string,
    { ref: ConferenceRef | null; games: Game[] }
  >();
  const push = (ref: ConferenceRef | null, game: Game) => {
    const key = ref ? conferenceToken(ref) : "other";
    const bucket = byConference.get(key);
    if (bucket) bucket.games.push(game);
    else byConference.set(key, { ref, games: [game] });
  };
  for (const game of visible) {
    const known = knownConferenceIds(game);
    if (known.length === 0) {
      push(null, game);
    } else {
      for (const id of known) push({ league: game.league, id }, game);
    }
  }

  // A followed team's conference floats to the top — as does an explicitly
  // followed conference; then P4 → G5 → Independents → Other.
  const floated = new Set<string>(followedConferenceTokens);
  for (const game of visible) {
    for (const side of [game.homeTeam, game.awayTeam]) {
      if (!followedTeamKeys.has(followKey({ league: game.league, teamId: side.team.id }))) {
        continue;
      }
      const confId = numericConferenceId(side.team.conferenceId);
      if (confId !== undefined) {
        floated.add(conferenceToken({ league: game.league, id: confId }));
      }
    }
  }

  const ordered = [...byConference.entries()].sort(
    ([lhsKey, lhs], [rhsKey, rhs]) => {
      const lf = floated.has(lhsKey);
      const rf = floated.has(rhsKey);
      if (lf !== rf) return lf ? -1 : 1;
      const lt = tierRank(lhs.ref ? tier(lhs.ref.id, lhs.ref.league) : "other");
      const rt = tierRank(rhs.ref ? tier(rhs.ref.id, rhs.ref.league) : "other");
      if (lt !== rt) return lt - rt;
      return conferenceNameFor(lhs.ref) < conferenceNameFor(rhs.ref) ? -1 : 1;
    }
  );

  for (const [key, bucket] of ordered) {
    const name = conferenceNameFor(bucket.ref);
    sections.push({
      id: `conf-${key}`,
      title: name,
      kind: "conference",
      games: bucket.games,
      logoUrl: bucket.ref
        ? conferenceLogoUrl(bucket.ref.id, bucket.ref.league)
        : undefined,
      conference: bucket.ref ?? undefined,
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
  const followedTeamKeys =
    options.followedTeamKeys instanceof Set
      ? options.followedTeamKeys
      : new Set(options.followedTeamKeys);
  const followedConferenceTokens =
    options.followedConferenceTokens instanceof Set
      ? options.followedConferenceTokens
      : new Set(options.followedConferenceTokens);

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
    isFollowed(game, followedTeamKeys, followedConferenceTokens)
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
        followedTeamKeys,
        followedConferenceTokens,
        options.top25RanksAvailable ?? true
      )
    );
  } else {
    sections.push(...daySections(visible));
  }
  return sections;
}
