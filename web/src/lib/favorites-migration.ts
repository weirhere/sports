// Pure migration for persisted favorites: legacy mock ids ("t-1") and
// prefixed ids ("espn-333") normalize to bare ESPN numeric-string ids;
// conference follows are filtered to the known FBS group ids. Idempotent —
// running it over already-migrated data is a no-op. (Wired into
// use-favorites in a later phase; this module is deliberately pure.)

import { conferenceName } from "@/lib/conferences";

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

export function migrateFavorites(
  teams: string[],
  confs: string[]
): { teams: string[]; confs: string[] } {
  const migratedTeams: string[] = [];
  const seenTeams = new Set<string>();
  for (const id of teams) {
    const normalized = normalizeTeamId(id);
    if (normalized === null || seenTeams.has(normalized)) continue;
    seenTeams.add(normalized);
    migratedTeams.push(normalized);
  }

  const migratedConfs: string[] = [];
  const seenConfs = new Set<string>();
  for (const id of confs) {
    if (!/^\d+$/.test(id)) continue;
    // Only the 11 known FBS group ids survive; anything else (FCS
    // conferences, junk) drops.
    if (conferenceName(Number(id)) === "Other") continue;
    if (seenConfs.has(id)) continue;
    seenConfs.add(id);
    migratedConfs.push(id);
  }

  return { teams: migratedTeams, confs: migratedConfs };
}
