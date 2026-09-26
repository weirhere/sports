// What the search page opens on once you've used it — the web twin of iOS
// `RecentSearchesStore` (sports/Stores/RecentSearchesStore.swift,
// 2026-09-21). Pure list operations plus the one storage read and write;
// the React half is `hooks/use-recent-searches`.
//
// **The result is remembered, not the query.** Typing "geor" and opening
// Georgia hands back *Georgia* — one tap from the page — rather than four
// letters and a second search.
//
// **The three storage shapes are three answers to staleness**, as on iOS:
// - A team or a conference persists as `(id, league)` and resolves against
//   the live directory (or the conference registry) at render time, so no
//   logo URL rots in storage and a change to `Team` needs no migration.
// - A player is a **snapshot**: there is no athlete directory to resolve an
//   id against, and re-asking ESPN on every render would make opening an
//   empty search box cost a request. A traded player wears his old club here
//   until he is opened again. The web's snapshot also carries the team id,
//   because its player route needs one (`lib/athlete-search`).
// - A game persists as `(id, league, day)` and resolves against the loaded
//   slate, never a snapshot: a stored score would freeze the moment the game
//   went live, and a frozen score is worse than no row.
//
// **Lifetime — decided for the web, not inherited (2026-09-25).** iOS keeps
// these in `UserDefaults`, per install, gone with a reinstall. The web keeps
// them in `localStorage`: per browser and per origin, surviving reloads,
// tab closes and restarts, and nothing like a reinstall — they go only when
// the visitor clears site data (or a private window closes). They are not
// synced across devices, and a second browser starts empty. That is the
// right lifetime for "where I just was": `sessionStorage` would forget it
// between visits, which is the whole point of the list.

import { isLeague, type League } from "./leagues";

export type RecentSearch =
  | { kind: "team"; id: string; league: League }
  | { kind: "conference"; id: number; league: League }
  | {
      kind: "player";
      id: string;
      league: League;
      name: string;
      teamName?: string;
      teamId: string;
      headshotUrl?: string;
    }
  | {
      kind: "game";
      id: string;
      league: League;
      /** The kickoff, kept for parity with iOS's `(id, day)` — resolution
       *  is by id; the day is what a future wider lookup would ask for. */
      day?: string;
    };

/**
 * Most-recent-first. Ten is a list you scan, not one you scroll: past that
 * it stops being "where I just was" and starts being history, which is a
 * different feature with a different screen.
 */
export const RECENT_SEARCHES_LIMIT = 10;

export const RECENT_SEARCHES_KEY = "search.recents";

/**
 * Stable across leagues, which is the whole point — ESPN's ids collide
 * between them (Auburn and the Bills are both team 2), and this list always
 * spans them. League-qualified for games too, where iOS keys on the event
 * id alone: the web's game routes are league-qualified already.
 */
export function recentSearchId(entry: RecentSearch): string {
  switch (entry.kind) {
    case "team":
      return `team.${entry.league}.${entry.id}`;
    case "conference":
      return `conf.${entry.league}.${entry.id}`;
    case "player":
      return `player.${entry.league}.${entry.id}`;
    case "game":
      return `game.${entry.league}.${entry.id}`;
  }
}

/**
 * Moves an entry to the front, or adds it there. Re-opening something
 * already listed reorders rather than duplicating, so the list reads as
 * recency and never as frequency — and matching on the id rather than
 * equality means a player whose snapshot changed reorders, not doubles.
 */
export function recordRecent(
  entries: readonly RecentSearch[],
  entry: RecentSearch
): RecentSearch[] {
  const id = recentSearchId(entry);
  return [entry, ...entries.filter((e) => recentSearchId(e) !== id)].slice(
    0,
    RECENT_SEARCHES_LIMIT
  );
}

/** Drops one entry — the dismiss control on its row. Keyed on the id so a
 *  drifted snapshot still matches the row that was tapped. */
export function removeRecent(
  entries: readonly RecentSearch[],
  entry: RecentSearch
): RecentSearch[] {
  const id = recentSearchId(entry);
  return entries.filter((e) => recentSearchId(e) !== id);
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

/** One stored entry, validated. Anything malformed is dropped, not thrown:
 *  storage is written by older builds and by hand in devtools alike. */
function parseEntry(value: unknown): RecentSearch | undefined {
  if (typeof value !== "object" || value === null) return undefined;
  const raw = value as Record<string, unknown>;
  const league = typeof raw.league === "string" ? raw.league : undefined;
  if (!isLeague(league)) return undefined;
  switch (raw.kind) {
    case "team": {
      const id = optionalString(raw.id);
      return id ? { kind: "team", id, league } : undefined;
    }
    case "conference":
      return typeof raw.id === "number" && Number.isInteger(raw.id)
        ? { kind: "conference", id: raw.id, league }
        : undefined;
    case "player": {
      const id = optionalString(raw.id);
      const name = optionalString(raw.name);
      const teamId = optionalString(raw.teamId);
      if (!id || !name || !teamId) return undefined;
      return {
        kind: "player",
        id,
        league,
        name,
        teamId,
        teamName: optionalString(raw.teamName),
        headshotUrl: optionalString(raw.headshotUrl),
      };
    }
    case "game": {
      const id = optionalString(raw.id);
      return id
        ? { kind: "game", id, league, day: optionalString(raw.day) }
        : undefined;
    }
    default:
      return undefined;
  }
}

/** The stored list, deduped and capped. Garbage in reads as empty. */
export function parseRecents(raw: string | null | undefined): RecentSearch[] {
  if (!raw) return [];
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return [];
  }
  if (!Array.isArray(parsed)) return [];
  const seen = new Set<string>();
  const out: RecentSearch[] = [];
  for (const value of parsed) {
    const entry = parseEntry(value);
    if (!entry) continue;
    const id = recentSearchId(entry);
    if (seen.has(id)) continue;
    seen.add(id);
    out.push(entry);
    if (out.length === RECENT_SEARCHES_LIMIT) break;
  }
  return out;
}

type ReadableStorage = Pick<Storage, "getItem">;
type WritableStorage = Pick<Storage, "setItem">;

/**
 * Every access wrapped: `localStorage` throws outright in some private
 * modes and when site data is blocked, and a search page that can't
 * remember is still a search page.
 */
export function readRecents(storage: ReadableStorage | undefined): RecentSearch[] {
  if (!storage) return [];
  try {
    return parseRecents(storage.getItem(RECENT_SEARCHES_KEY));
  } catch {
    return [];
  }
}

export function writeRecents(
  storage: WritableStorage | undefined,
  entries: readonly RecentSearch[]
): void {
  if (!storage) return;
  try {
    storage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(entries));
  } catch {
    // Quota or blocked storage: the list lives for this page view only.
  }
}
