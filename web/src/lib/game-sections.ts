// The Scores sectioning engine — a port of iOS `LeagueScoreboards.sections`
// (sports/Stores/LeagueScoreboards.swift).
//
// Assembly moved up from the per-league store on 2026-09-05: the sections
// span leagues now, so no single-league store can build them. What comes in
// is one day's games across every league plus the follow sets; what goes out
// is the ordered stack the screen renders.
//
// The product rules that shape all of it:
//
//   1. **Sections are complete, never deduplicated.** A game appears in
//      every section whose promise it satisfies — Following, a followed
//      table's, and both conferences of a cross-conference matchup. The one
//      thing that never doubles is a section with itself: a followed
//      conference *moves* up the page rather than being cloned.
//   2. **Following is your teams.** A followed conference used to pour its
//      whole slate in here; since 2026-09-06 it doesn't — a Big Ten follow
//      is ~8 games on a Saturday, which buries the three you care about.
//      A followed table earns a section of its own directly beneath.
//   3. **College football breaks down by conference; nobody else does.**
//      One "College Football" accordion is 60 rows on a Saturday with no way
//      in. The NFL's 16, the NBA's 11 and the NHL's 8 are each the whole
//      slate at a glance, and their divisions would be one or two rows a
//      section. `slateSplitsByConference` decides, so the stack is one loop
//      rather than a branch per league.
//   4. **Live is a state; the filter is a scope.** Live composes with
//      everything. The filter narrows the stack and leaves Following alone —
//      narrowing "my games" to the SEC would silently empty the section for
//      a Michigan fan, which is the mystery state the labeled chip exists to
//      avoid. A filter also hides the leagues it can't speak for outright
//      rather than emptying them: "SEC" is not a question the NFL's slate
//      can answer.

import {
  collegeDivision,
  conferenceLogoUrl,
  conferenceName,
  conferenceNameFor,
  tier,
  tierRank,
  type CollegeDivision,
} from "./conferences";
import {
  tableLogoUrl,
  tableMatches,
  tableName,
  tableToken,
  tableLeague,
  type FollowedTable,
} from "./followed-tables";
import { isTight } from "./game-closeness";
import {
  LEAGUES,
  LEAGUE_DISPLAY_ORDER,
  displayName,
  leagueLogoUrl,
  slateSplitsByConference,
  type League,
} from "./leagues";
import { conferenceToken, followKey, type ConferenceRef } from "./refs";
import type { Game, GameStatus } from "./types";

/**
 * The slate filter's persisted spelling — `"top25"` or `"conference-cfb:8"`.
 * `null` means all games.
 *
 * The conference half is league-qualified because group 8 is the SEC and the
 * AFC. A pre-axis `"conference-8"` still parses, as college football's.
 */
export type ScoreFilterToken = string;

export const FOLLOWING_SECTION_ID = "following";

export type SectionKind = "following" | "table" | "league" | "conference";

export interface GameSection {
  /** Stable across refetches — expansion state keys off this. */
  id: string;
  title: string;
  kind: SectionKind;
  games: Game[];
  /** The mark for the header. */
  logoUrl?: string;
  /**
   * Which league this section is about, where it is about one. Following
   * spans them, so it has none — which is also what stops it taking a
   * league tag.
   */
  league?: League;
  /**
   * The conference this section is, when it is one — what the header's name
   * link navigates with. The "Other" bucket has none.
   */
  conference?: ConferenceRef;
  /**
   * The followable table this section *is*, so a follow hoists this very
   * section rather than cloning it.
   */
  table?: FollowedTable;
  /**
   * True on the sections that are *yours*: Following, and a followed table
   * hoisted to lead the stack (iOS `GameSection.isFollowed`, 2026-09-22).
   * Never merely because a section carries a `table` — every conference
   * section does, followed or not, so it can be matched for hoisting. This
   * is the line the Hide all/Show all control draws.
   */
  isFollowed?: boolean;
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

// --- The slate filter --------------------------------------------------

export function conferenceFilterToken(ref: ConferenceRef): ScoreFilterToken {
  return `conference-${conferenceToken(ref)}`;
}

export function parseConferenceFilter(
  token: ScoreFilterToken | null | undefined
): ConferenceRef | undefined {
  if (!token || !token.startsWith("conference-")) return undefined;
  const rest = token.slice("conference-".length);
  const separator = rest.indexOf(":");
  if (separator === -1) {
    // Pre-axis tokens were bare group ids, always college football's.
    const id = Number(rest);
    return Number.isInteger(id) ? { league: "cfb", id } : undefined;
  }
  const league = rest.slice(0, separator);
  const id = Number(rest.slice(separator + 1));
  if (!Number.isInteger(id)) return undefined;
  return (LEAGUES as readonly string[]).includes(league)
    ? { league: league as League, id }
    : undefined;
}

/** The league a filter can speak for, or undefined when it spans them. */
export function filterLeague(
  token: ScoreFilterToken | null | undefined
): League | undefined {
  if (!token) return undefined;
  // The poll is college football's, so a Top 25 filter scopes to it.
  if (token === "top25") return "cfb";
  return parseConferenceFilter(token)?.league;
}

export function isValidScoreFilterToken(token: string): boolean {
  return token === "top25" || parseConferenceFilter(token) !== undefined;
}

/** The sheet/empty-state name for a filter token ("SEC", "Top 25"). */
export function scoreFilterLabel(token: ScoreFilterToken): string {
  if (token === "top25") return "Top 25";
  const ref = parseConferenceFilter(token);
  return ref !== undefined ? conferenceName(ref.id, ref.league) : token;
}

/**
 * The header chip's label — long conference names get their common short
 * forms so the chip row still fits (the iOS `chipLabel` table).
 */
export function scoreFilterChipLabel(token: ScoreFilterToken): string {
  const ref = parseConferenceFilter(token);
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

function matchesFilter(game: Game, token: ScoreFilterToken): boolean {
  if (token === "top25") return involvesRankedTeam(game);
  const ref = parseConferenceFilter(token);
  if (ref === undefined) return true;
  if (game.league !== ref.league) return false;
  return [game.homeTeam, game.awayTeam].some(
    (side) => numericConferenceId(side.team.conferenceId) === ref.id
  );
}

// --- Ordering ----------------------------------------------------------

/** Kickoff order, ties broken by id; games without a parseable date sink. */
export function chronological(games: readonly Game[]): Game[] {
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

/**
 * Live first, then upcoming, then finals, then the postponed and canceled —
 * a row with nothing to watch and no result sits last.
 */
function stateRank(status: GameStatus): number {
  if (isLiveStatus(status)) return 0;
  if (status === "scheduled" || status === "delayed") return 1;
  if (status === "complete") return 2;
  return 3;
}

/**
 * Following's order: what's happening now, then what's about to, then what
 * already did.
 *
 * The section is a Saturday's worth of one fan's games at once, so a final
 * has nothing left to say while a live game changes every play —
 * chronological alone buried the live row under the morning's results.
 * Within a state the clock still orders them.
 */
function byState(games: readonly Game[]): Game[] {
  return [...games].sort((a, b) => {
    const [ra, rb] = [stateRank(a.status), stateRank(b.status)];
    if (ra !== rb) return ra - rb;
    const [at, bt] = [Date.parse(a.scheduledAt), Date.parse(b.scheduledAt)];
    const [aValid, bValid] = [Number.isFinite(at), Number.isFinite(bt)];
    if (aValid && bValid && at !== bt) return at - bt;
    if (aValid !== bValid) return aValid ? -1 : 1;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });
}

// --- Section builders --------------------------------------------------

/** A league that stands as one section — its whole night at a glance. */
function leagueSection(league: League, games: Game[]): GameSection {
  return {
    id: `league-${league}`,
    title: displayName(league),
    kind: "league",
    games,
    league,
    logoUrl: leagueLogoUrl(league),
  };
}

/**
 * College football's slate, one section per conference — the way fans carve
 * up a Saturday.
 *
 * A cross-conference game lands in both sections. "Other" is a last resort
 * for games no section can claim: an FCS visitor at an FBS school stays in
 * the host's conference only, or Week 1's ~48 FCS matchups would pile up in
 * Other as duplicates.
 *
 * The buckets follow the **slate's** divisions, not the registry's
 * knowledge: FCS is opt-in, so until someone follows an FCS conference a Big
 * Sky visitor stays in its host's section rather than spawning a Big Sky one.
 */
function conferenceSections(
  games: Game[],
  league: League,
  divisions: ReadonlySet<CollegeDivision>
): GameSection[] {
  if (games.length === 0) return [];

  const buckets = new Map<
    string,
    { ref: ConferenceRef | undefined; games: Game[] }
  >();
  const push = (ref: ConferenceRef | undefined, game: Game) => {
    const key = ref ? conferenceToken(ref) : "other";
    const bucket = buckets.get(key);
    if (bucket) bucket.games.push(game);
    else buckets.set(key, { ref, games: [game] });
  };

  for (const game of games) {
    const claimed = new Map<string, ConferenceRef>();
    for (const side of [game.homeTeam, game.awayTeam]) {
      const id = numericConferenceId(side.team.conferenceId);
      if (id === undefined) continue;
      const division = collegeDivision(id, league);
      if (division === undefined || !divisions.has(division)) continue;
      claimed.set(conferenceToken({ league, id }), { league, id });
    }
    if (claimed.size === 0) push(undefined, game);
    else for (const ref of claimed.values()) push(ref, game);
  }

  // P4 → G5 → Independents → FCS → Other, alphabetical within a tier.
  const ordered = [...buckets.values()].sort((lhs, rhs) => {
    const lt = tierRank(lhs.ref ? tier(lhs.ref.id, league) : "other");
    const rt = tierRank(rhs.ref ? tier(rhs.ref.id, league) : "other");
    if (lt !== rt) return lt - rt;
    return conferenceNameFor(lhs.ref) < conferenceNameFor(rhs.ref) ? -1 : 1;
  });

  return ordered.map((bucket) => ({
    id: bucket.ref ? `conf-${conferenceToken(bucket.ref)}` : `other-${league}`,
    title: conferenceNameFor(bucket.ref),
    kind: "conference" as const,
    games: bucket.games,
    league,
    logoUrl: bucket.ref
      ? conferenceLogoUrl(bucket.ref.id, bucket.ref.league)
      : undefined,
    conference: bucket.ref,
    table: bucket.ref
      ? ({ kind: "conference", ref: bucket.ref } as FollowedTable)
      : undefined,
  }));
}

export interface BuildSectionsOptions {
  /**
   * Followed teams as league-qualified keys (`"cfb:130"`), never bare ids:
   * ESPN id 5 is UAB *and* the Browns.
   */
  followedTeamKeys: ReadonlySet<string> | readonly string[];
  /** Followed tables in the user's own order — they lead the stack. */
  followedTables?: readonly FollowedTable[];
  liveOnly?: boolean;
  /**
   * The Tight filter (iOS, 2026-09-24): live and late within one score, or
   * with the underdog leading — `isTight`. A narrower Live, so it composes
   * with everything Live does.
   */
  tightOnly?: boolean;
  scoreFilter?: ScoreFilterToken | null;
  /**
   * The college-football divisions the slate was fetched with. FCS is
   * opt-in, so a Big Sky visitor only spawns a Big Sky section once someone
   * follows one.
   */
  divisions?: ReadonlySet<CollegeDivision>;
}

/**
 * One day's slate as the screen renders it: Following, then the tables you
 * follow, then the day's whole stack.
 */
export function buildSections(
  games: readonly Game[],
  options: BuildSectionsOptions
): GameSection[] {
  const followedTeamKeys =
    options.followedTeamKeys instanceof Set
      ? options.followedTeamKeys
      : new Set(options.followedTeamKeys);
  const followedTables = options.followedTables ?? [];
  const divisions = options.divisions ?? new Set<CollegeDivision>(["FBS"]);
  const filter = options.scoreFilter ?? null;
  const scope = filterLeague(filter);

  const following: Game[] = [];
  // Per league, the games the stack is allowed to show. Following is claimed
  // *before* the filter narrows anything, so a followed team stays visible
  // while the slate below is scoped.
  const visible = new Map<League, Game[]>();

  for (const league of LEAGUES) {
    let slate = games.filter((game) => game.league === league);
    if (options.liveOnly) slate = slate.filter((g) => isLiveStatus(g.status));
    if (options.tightOnly) slate = slate.filter(isTight);
    for (const game of slate) {
      const claimed = [game.homeTeam, game.awayTeam].some((side) =>
        followedTeamKeys.has(followKey({ league, teamId: side.team.id }))
      );
      if (claimed) following.push(game);
    }
    if (filter !== null) {
      // A filter hides the leagues it can't speak for outright rather than
      // emptying them.
      if (scope !== undefined && scope !== league) continue;
      slate = slate.filter((game) => matchesFilter(game, filter));
    }
    visible.set(league, chronological(slate));
  }

  // The full slate, in its resting order — A–Z by league (2026-09-24), which
  // is also the Leagues hub's.
  const stack: GameSection[] = [];
  for (const league of LEAGUE_DISPLAY_ORDER) {
    const slate = visible.get(league) ?? [];
    if (slate.length === 0) continue;
    stack.push(
      ...(slateSplitsByConference(league)
        ? conferenceSections(slate, league, divisions)
        : [leagueSection(league, slate)])
    );
  }

  // Followed tables lead the stack, in the user's order. One already in it
  // moves; one that isn't (a poll, an NFL conference) is built here.
  const hoisted: GameSection[] = [];
  const hoistedIds = new Set<string>();
  for (const table of followedTables) {
    const league = tableLeague(table);
    if (scope !== undefined && scope !== league) continue;
    const token = tableToken(table);
    const existing = stack.find(
      (section) =>
        section.table !== undefined && tableToken(section.table) === token
    );
    if (existing) {
      if (hoistedIds.has(existing.id)) continue;
      hoistedIds.add(existing.id);
      hoisted.push({ ...existing, isFollowed: true });
      continue;
    }
    const slate = (visible.get(league) ?? []).filter((game) =>
      tableMatches(table, game)
    );
    if (slate.length === 0 || hoistedIds.has(token)) continue;
    hoistedIds.add(token);
    hoisted.push({
      id: token,
      title: tableName(table),
      kind: "table",
      games: slate,
      league,
      logoUrl: tableLogoUrl(table),
      conference: table.kind === "conference" ? table.ref : undefined,
      table,
      isFollowed: true,
    });
  }

  const result: GameSection[] = [];
  if (following.length > 0) {
    result.push({
      id: FOLLOWING_SECTION_ID,
      title: "Following",
      kind: "following",
      games: byState(following),
      isFollowed: true,
    });
  }
  return [
    ...result,
    ...hoisted,
    ...stack.filter((section) => !hoistedIds.has(section.id)),
  ];
}

// --- Hide all / Show all -----------------------------------------------

/**
 * Splits a day's sections into what's yours — Following plus every hoisted
 * table — and the rest, which is where the Hide all/Show all control sits
 * (iOS `ScoresScreen.scoresRows(for:hideOthers:)`, 2026-09-22). Only where
 * both sides are non-empty: following nobody leaves nothing to set apart,
 * and following enough to cover the whole day leaves nothing to hide, so
 * the control is omitted rather than shown inert.
 *
 * The split doesn't read the hidden state: iOS drops the hidden sections
 * from its rows, while the web keeps `others` so the screen can animate the
 * stack closed rather than cut it.
 */
export function splitAtHideAll(sections: readonly GameSection[]): {
  mine: GameSection[];
  others: GameSection[];
  /** False when there's no boundary to draw; `mine` is then everything. */
  hasBoundary: boolean;
} {
  const mine = sections.filter((section) => section.isFollowed === true);
  const others = sections.filter((section) => section.isFollowed !== true);
  if (mine.length === 0 || others.length === 0) {
    return { mine: [...sections], others: [], hasBoundary: false };
  }
  return { mine, others, hasBoundary: true };
}

/**
 * The line under Show all — "Big Ten, SEC and 2 other leagues, conferences
 * or divisions play today" (iOS `HideAllControl.summary(of:)`, 2026-09-25).
 * The first two sections are named in slate order and the rest counted. A
 * catch-all "Other" section is never one of the two named — "Big Ten, Other
 * and…" names nothing — but it still counts.
 */
export function hiddenSectionsSummary(
  sections: readonly Pick<GameSection, "id" | "title">[]
): string {
  const named = sections
    .filter((section) => !section.id.startsWith("other-"))
    .slice(0, 2)
    .map((section) => section.title);
  const rest = sections.length - named.length;
  const parts = [...named];
  if (rest > 0) {
    parts.push(
      rest === 1
        ? "1 other league, conference or division"
        : `${rest} other leagues, conferences or divisions`
    );
  }
  const list =
    parts.length <= 1
      ? (parts[0] ?? "")
      : `${parts.slice(0, -1).join(", ")} and ${parts[parts.length - 1]}`;
  return list + (sections.length === 1 ? " plays today" : " play today");
}
