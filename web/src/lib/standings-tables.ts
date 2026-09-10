// Derivations over a league's standings tables — a port of the iOS
// `[ConferenceStandings]` extensions (StatSideShared/Models/ConferenceStandings.swift).
//
// What ESPN hands back is a flat list of groups. What the Leagues hub and
// the entity pages need is that list read three ways: folded up to one row
// per conference, split down to the divisions under one, or merged into the
// league's own single table. None of those is a second request.

import {
  conferenceChain,
  conferenceName,
  isKnownConference,
  leagueWideId,
  tier,
  tierRank,
  topLevelIds,
} from "./conferences";
import type { League } from "./leagues";
import { conferenceToken, sameConference, type ConferenceRef } from "./refs";
import type { StandingsScope } from "./standings-scope";
import type { ConferenceStanding, ConferenceStandingsGroup } from "./types";

export function tableRef(
  table: ConferenceStandingsGroup
): ConferenceRef | undefined {
  const id = Number(table.id);
  return Number.isInteger(id) ? { league: table.league, id } : undefined;
}

/** The mappers' own order: tier, then name. */
function byTierThenName(
  a: ConferenceStandingsGroup,
  b: ConferenceStandingsGroup
): number {
  const at = tierRank(tier(Number(a.id), a.league));
  const bt = tierRank(tier(Number(b.id), b.league));
  if (at !== bt) return at - bt;
  return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
}

function merged(
  divisions: ConferenceStandingsGroup[],
  id: number,
  name: string,
  league: League
): ConferenceStandingsGroup | undefined {
  if (divisions.length === 0) return undefined;
  return {
    id: String(id),
    league,
    name,
    entries: divisions.flatMap((division) => division.entries),
    spansDivisions: divisions.length > 1,
  };
}

/**
 * One row per conference, divisions folded into their parent — the Sun
 * Belt, not "Sun Belt - East" and "Sun Belt - West"; the AFC, not its four.
 *
 * For lists that *name* conferences rather than table them. The standings
 * themselves still keep each division's table: this is a display fold, and
 * the folded row says so (`spansDivisions`), so nothing reads a division
 * leader as the conference's.
 *
 * Divisions whose parent we can't name pass through unfolded — a merged row
 * has to be able to say which conference it is. Re-sorts by tier-then-name,
 * which the fold can change: an unknown division id sorts last, its
 * conference doesn't. That re-sort is also what puts FBS above FCS when
 * both divisions are folded in one pass.
 */
export function foldingDivisions(
  tables: readonly ConferenceStandingsGroup[]
): ConferenceStandingsGroup[] {
  const folded: ConferenceStandingsGroup[] = [];
  const mergedParents = new Set<string>();
  // A conference that arrived as a real table of its own is never
  // rebuilt from its divisions: ESPN's own order for it encodes
  // tiebreakers, where a merge is each division's list in turn and ranks
  // nothing across them.
  const real = new Set(
    tables
      .filter((table) => table.parentId === undefined && table.entries.length > 0)
      .map((table) => conferenceToken({ league: table.league, id: Number(table.id) }))
  );

  // Conferences that have divisions in this list. An empty container —
  // which is how `level=3` ships them — must not shadow the merge that
  // replaces it.
  const hasDivisions = new Set(
    tables
      .filter((table) => table.parentId !== undefined)
      .map((table) =>
        conferenceToken({ league: table.league, id: table.parentId! })
      )
  );

  for (const table of tables) {
    const parentId = table.parentId;
    if (parentId === undefined || tier(parentId, table.league) === "other") {
      const own = conferenceToken({
        league: table.league,
        id: Number(table.id),
      });
      if (table.entries.length === 0 && hasDivisions.has(own)) continue;
      folded.push(table);
      continue;
    }
    const parent: ConferenceRef = { league: table.league, id: parentId };
    const token = conferenceToken(parent);
    if (mergedParents.has(token) || real.has(token)) continue;
    mergedParents.add(token);
    const divisions = tables.filter(
      (other) =>
        other.parentId === parentId && other.league === table.league
    );
    const row = merged(
      divisions,
      parentId,
      conferenceName(parentId, table.league),
      table.league
    );
    if (row) folded.push(row);
  }
  return folded.sort(byTierThenName);
}

/**
 * The whole league as one table: every top-level table's entries in one
 * list, ranked by ESPN's win percentage — or by points where the league
 * keeps those instead.
 *
 * Built from the conference tables already fetched rather than from
 * `standings?level=1`, which costs a request to answer worse: its
 * current-season order is this same win-percentage ranking, but its
 * past-season order is a stale seed interleave that puts a 14-2 Baltimore
 * ninth (probed live 2026-09-05).
 *
 * Ordering here doesn't breach the never-sort-standings rule — that rule
 * protects orders encoding tiebreakers, and a league ranks nothing across
 * its conferences. Ties keep the source tables' order rather than inventing
 * a winner between them.
 *
 * Undefined unless **every** top-level group came back: a table calling
 * itself the NFL with one conference missing is a lie the row can't qualify.
 */
export function leagueTable(
  tables: readonly ConferenceStandingsGroup[],
  league: League
): ConferenceStandingsGroup | undefined {
  const wideId = leagueWideId(league);
  if (wideId === undefined) return undefined;
  const top = tables.filter(
    (table) => table.league === league && table.parentId === undefined
  );
  const present = new Set(top.map((table) => Number(table.id)));
  if (!topLevelIds(league).every((id) => present.has(id))) return undefined;

  const entries = top.flatMap((table) => table.entries);
  if (entries.length === 0) return undefined;

  // The NHL ships no `winpercent` at all, so ranking on it fell to the
  // source-order tiebreak and the "NHL" table came back East's seeds then
  // West's — a table calling itself a ranking while ranking nothing.
  const rank = (entry: ConferenceStanding): number | undefined =>
    league === "nhl" ? entry.points : entry.winPercent;

  const ordered = entries
    .map((entry, index) => ({ entry, index }))
    .sort((a, b) => {
      const [l, r] = [rank(a.entry), rank(b.entry)];
      if (l === undefined || r === undefined || l === r) return a.index - b.index;
      return r - l;
    })
    .map(({ entry }) => entry);

  return {
    id: String(wideId),
    league,
    name: conferenceName(wideId, league),
    entries: ordered,
  };
}

/**
 * The divisions a league's accordion lists, grouped by the conference they
 * belong to and alphabetical inside it — the AFC's four, then the NFC's.
 *
 * The mapper sorts divisions by name alone, which is right for a standings
 * pane listing one conference's and wrong for a list of every one:
 * alphabetically the NBA's six interleave their conferences, and Northwest
 * lands between Central and Pacific with nothing on screen to explain why.
 */
export function divisionsIn(
  tables: readonly ConferenceStandingsGroup[],
  league: League
): ConferenceStandingsGroup[] {
  const order = topLevelIds(league);
  const rank = (table: ConferenceStandingsGroup) => {
    if (table.parentId === undefined) return order.length;
    const index = order.indexOf(table.parentId);
    return index === -1 ? order.length : index;
  };
  return tables
    .filter((table) => table.league === league && table.parentId !== undefined)
    .sort((a, b) => {
      const [l, r] = [rank(a), rank(b)];
      if (l !== r) return l - r;
      return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
    });
}

/**
 * Whether a standing has played inside its group yet.
 *
 * Asks the question rather than testing one league's field: the NHL keeps
 * no conference record at all, so a `conferenceRecord !== "0-0"` test was
 * undefined there and every hockey card would have hidden its leader
 * forever.
 */
function hasStartedInGroupPlay(entry: ConferenceStanding): boolean {
  const record = entry.conferenceRecord ?? entry.overallRecord;
  if (record === undefined) return entry.overallWins + entry.overallLosses > 0;
  return !/^0-0(-0)?$/.test(record.trim());
}

/**
 * The leader a row teases, or undefined where teasing one would lie.
 *
 * A folded divisional table ranks nothing across its divisions, so its
 * first entry is a *division* leader, not the conference's. And a preseason
 * 0-0 "leader" is last season's carry-over.
 */
export function leaderOf(
  table: ConferenceStandingsGroup
): ConferenceStanding | undefined {
  if (table.spansDivisions) return undefined;
  const first = table.entries[0];
  if (first === undefined || !hasStartedInGroupPlay(first)) return undefined;
  return first;
}

/**
 * The record a leader teaser shows.
 *
 * The in-group record where the league keeps one, the overall otherwise —
 * the NHL ships no `vsconf`, so every hockey row on the hub sat bare, name
 * and a follow star, while the NBA rows above it read "Boston · 36-16".
 */
export function leaderRecord(entry: ConferenceStanding): string | undefined {
  return entry.conferenceRecord ?? entry.overallRecord;
}

/** Whether this table is its league's whole-league row. */
export function isLeagueWide(table: ConferenceStandingsGroup): boolean {
  return Number(table.id) === leagueWideId(table.league);
}

/**
 * Every table a league offers that someone could be following, including
 * the conference rows the accordion no longer lists.
 *
 * A conference follow made before the hub showed divisions still has a card
 * in Following and still hoists its section on Scores.
 */
export function followableTables(
  listed: readonly ConferenceStandingsGroup[],
  conferences: readonly ConferenceStandingsGroup[]
): ConferenceStandingsGroup[] {
  const seen = new Set<string>();
  return [...listed, ...conferences].filter((table) => {
    const ref = tableRef(table);
    const key = ref ? conferenceToken(ref) : `unknown-${table.name}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

export function findTable(
  tables: readonly ConferenceStandingsGroup[],
  ref: ConferenceRef
): ConferenceStandingsGroup | undefined {
  return tables.find((table) => sameConference(tableRef(table), ref));
}

/** Whether the registry can name this table — the gate for a follow star. */
export function isFollowable(table: ConferenceStandingsGroup): boolean {
  const ref = tableRef(table);
  return ref !== undefined && isKnownConference(ref.id, ref.league);
}

/**
 * The tables a page shows at one scope.
 *
 * `division` is three different questions wearing one scope. A **league**
 * page shows every division. A **conference** page shows the ones under it.
 * A **division's own** page shows *itself* — it is one of these tables
 * rather than a parent of them, and asking for its children finds nothing,
 * which is how every division page said "Standings TBA" while the row that
 * pushed it was teasing that division's leader.
 */
export function tablesAtScope(
  tables: readonly ConferenceStandingsGroup[],
  anchor: ConferenceRef,
  scope: StandingsScope
): ConferenceStandingsGroup[] {
  // A scope names a **rung**, so the anchor is resolved to it first. A
  // conference page anchors on its own group and only ever scopes down, so
  // this is a no-op there — but a *team* page anchors on the team's
  // division and asking it for "Conference" means the conference above,
  // not a conference with the division's id.
  const ref = resolveToRung(anchor, scope);
  const wide = isLeagueWideId(ref);
  switch (scope) {
    case "league": {
      // Fold first: a `level=3` response carries only divisions, so the
      // conferences `leagueTable` merges have to be derived before they
      // can be merged again. Folding a shipped response is a no-op.
      const merged = leagueTable(conferencesOf(tables, ref.league), ref.league);
      return merged ? [merged] : [];
    }
    case "conference": {
      const conferences = conferencesOf(tables, ref.league);
      if (wide) return conferences;
      const own = conferences.filter((table) =>
        sameConference(tableRef(table), ref)
      );
      // **A divisional conference keeps its divisions as separate tables**
      // (iOS, 2026-09-05). Where the fold had to merge — no real
      // conference table came back, so its entries are each division's in
      // turn — one card per division is the only honest answer: a merged
      // table numbers teams 1 through 14 across divisions ESPN never
      // ranked against each other, which is tiebreaker guesswork printed
      // as a place column. A conference ESPN *does* rank keeps its own
      // table, because that order is real.
      if (own.length === 1 && own[0].spansDivisions) {
        return tablesAtScope(tables, ref, "division");
      }
      return own;
    }
    case "division": {
      const divisions = tables.filter(
        (table) => table.league === ref.league && table.parentId !== undefined
      );
      if (wide) return divisionsIn(tables, ref.league);
      // The page's own table, where the page *is* a division.
      const own = divisions.find((table) =>
        sameConference(tableRef(table), ref)
      );
      if (own) return [own];
      return divisions.filter((table) => table.parentId === ref.id);
    }
  }
}

/**
 * The link in this group's own chain that sits at the rung a scope names,
 * or the group itself where the chain doesn't reach it.
 */
function resolveToRung(
  ref: ConferenceRef,
  scope: StandingsScope
): ConferenceRef {
  if (scope === "division") return ref;
  const wanted = scope === "league" ? "league" : "conference";
  const link = conferenceChain(ref).find(
    (step) => tier(step.id, step.league) === wanted
  );
  return link ?? ref;
}

/** One row per conference, whatever depth the response arrived at. */
function conferencesOf(
  tables: readonly ConferenceStandingsGroup[],
  league: League
): ConferenceStandingsGroup[] {
  return foldingDivisions(tables.filter((table) => table.league === league));
}

function isLeagueWideId(ref: ConferenceRef): boolean {
  return leagueWideId(ref.league) === ref.id;
}

/**
 * A division table's own short name — "East", not "Sun Belt - East".
 *
 * ESPN writes the conference into every division's name, which is right in
 * a list of every division and repetitive on the page that already says it.
 */
export function divisionShortName(
  table: ConferenceStandingsGroup,
  parentName: string
): string {
  // ESPN writes "{Conference} - {Division}", and its conference half is
  // often longer than our registry's name for the same group ("American
  // Athletic" vs "American") — so the separator is what to cut on, not the
  // parent's name.
  const dash = table.name.indexOf(" - ");
  if (dash !== -1) return table.name.slice(dash + 3);
  // The registry's own spelling — "AFC East" under "AFC".
  const spaced = `${parentName} `;
  if (table.name.startsWith(spaced)) return table.name.slice(spaced.length);
  return table.name;
}
