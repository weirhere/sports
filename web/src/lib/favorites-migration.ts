// Pure migration for persisted favorites.
//
// v2 normalized legacy mock ids ("t-1") and prefixed ids ("espn-333") to
// bare ESPN numeric-string ids, and filtered conference follows to the
// known FBS group ids.
//
// v3 league-qualifies both sets: a follow becomes `"cfb:130"` and a
// conference follow `"cfb:8"`. Every stored value predates the league axis,
// so every one of them is college football's — the app had no other league
// — which makes the mapping exact rather than a guess. Idempotent: an
// already-qualified key passes through untouched.

import { FBS_GROUP_ID, collegeDivision } from "@/lib/conferences";
import { isLeague } from "@/lib/leagues";

/**
 * Frozen snapshot of the mock roster's id → ESPN id mapping
 * (web/src/lib/mock/teams.ts as of 2026-09-01). Frozen on purpose: stored
 * favorites were written against THIS mapping, so it must never drift with
 * the mock file. Note the mock carries duplicate espnIds (t-20/t-23 both
 * 2628, t-5/t-26 both 2305); migration dedupes, first wins.
 */
export const LEGACY_TEAM_ID_MAP: Readonly<Record<string, string>> = {
  "t-1": "333",
  "t-2": "2032",
  "t-3": "96",
  "t-4": "2633",
  "t-5": "2305",
  "t-6": "127",
  "t-7": "99",
  "t-8": "57",
  "t-9": "251",
  "t-10": "145",
  "t-11": "194",
  "t-12": "130",
  "t-13": "213",
  "t-14": "356",
  "t-15": "264",
  "t-16": "275",
  "t-17": "2294",
  "t-18": "228",
  "t-19": "2390",
  "t-20": "2628",
  "t-21": "59",
  "t-22": "2579",
  "t-23": "2628",
  "t-24": "2005",
  "t-25": "2132",
  "t-26": "2305",
  "t-27": "66",
  "t-28": "265",
  "t-29": "2483",
  "t-30": "2116",
  "t-31": "2653",
  "t-32": "2229",
  "t-33": "87",
  "t-34": "2",
};

function normalizeTeamId(id: string): string | null {
  const legacy = LEGACY_TEAM_ID_MAP[id];
  if (legacy !== undefined) return legacy;
  const prefixed = /^espn-(\d+)$/.exec(id);
  if (prefixed) return prefixed[1];
  if (/^\d+$/.test(id)) return id;
  return null;
}

/** Whether a stored value already carries a league prefix. */
function isQualified(value: string): boolean {
  const separator = value.indexOf(":");
  return separator > 0 && isLeague(value.slice(0, separator));
}

export function migrateFavorites(
  teams: string[],
  confs: string[]
): { teams: string[]; confs: string[] } {
  const migratedTeams: string[] = [];
  const seenTeams = new Set<string>();
  for (const id of teams) {
    if (isQualified(id)) {
      if (seenTeams.has(id)) continue;
      seenTeams.add(id);
      migratedTeams.push(id);
      continue;
    }
    const normalized = normalizeTeamId(id);
    if (normalized === null) continue;
    const key = `cfb:${normalized}`;
    if (seenTeams.has(key)) continue;
    seenTeams.add(key);
    migratedTeams.push(key);
  }

  const migratedConfs: string[] = [];
  const seenConfs = new Set<string>();
  for (const id of confs) {
    if (isQualified(id)) {
      if (seenConfs.has(id)) continue;
      seenConfs.add(id);
      migratedConfs.push(id);
      continue;
    }
    if (!/^\d+$/.test(id)) continue;
    // Only the 11 known FBS group ids survive; anything else (FCS
    // conferences, junk) drops. **Deliberately frozen at FBS**: stored
    // follows were written against that table, so this gate must not widen
    // as the live registry does — extend the registry, not this.
    const numeric = Number(id);
    if (numeric === FBS_GROUP_ID) continue;
    if (collegeDivision(numeric, "cfb") !== "FBS") continue;
    const token = `cfb:${id}`;
    if (seenConfs.has(token)) continue;
    seenConfs.add(token);
    migratedConfs.push(token);
  }

  return { teams: migratedTeams, confs: migratedConfs };
}
