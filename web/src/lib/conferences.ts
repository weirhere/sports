// FBS conference registry — a faithful port of the iOS app's `Conference`
// enum (StatSideShared/Models/Team.swift). ESPN group ids, hardcoded with an
// "other" fallback so an unknown id degrades to a bucket, never a crash.

export const FBS_GROUP_ID = 80;

export type ConferenceTier = "power4" | "group5" | "independent" | "other";

const CONFERENCE_NAMES: Record<number, string> = {
  1: "ACC",
  151: "American",
  4: "Big 12",
  5: "Big Ten",
  12: "Conference USA",
  18: "Independents",
  15: "MAC",
  17: "Mountain West",
  9: "Pac-12",
  8: "SEC",
  37: "Sun Belt",
};

const POWER_4 = new Set([1, 4, 5, 8]);

// ESPN CDN slugs, verified live against the /scoreboard/conferences endpoint
// (iOS, 2026-07-20). An unknown id just means no logo, never a broken image.
const LOGO_SLUGS: Record<number, string> = {
  1: "acc",
  151: "american",
  4: "big_12",
  5: "big_ten",
  12: "conference_usa",
  18: "fbs_independents",
  15: "mid_american",
  17: "mountain_west",
  9: "pac_12",
  8: "sec",
  37: "sun_belt",
};

export function conferenceName(id: number | null | undefined): string {
  if (id == null) return "Other";
  return CONFERENCE_NAMES[id] ?? "Other";
}

export function tier(id: number | null | undefined): ConferenceTier {
  if (id == null || CONFERENCE_NAMES[id] === undefined) return "other";
  if (POWER_4.has(id)) return "power4";
  if (id === 18) return "independent";
  return "group5";
}

/** Sort rank for tiers — mirrors the iOS `Tier` raw-value ordering. */
export function tierRank(t: ConferenceTier): number {
  switch (t) {
    case "power4":
      return 0;
    case "group5":
      return 1;
    case "independent":
      return 2;
    case "other":
      return 3;
  }
}

/**
 * Every known FBS conference in the app's browsing order: P4 → G5 →
 * Independents, alphabetical within each tier (the iOS `orderedIds`).
 */
export const orderedIds: number[] = Object.keys(CONFERENCE_NAMES)
  .map(Number)
  .sort((lhs, rhs) => {
    const [lt, rt] = [tierRank(tier(lhs)), tierRank(tier(rhs))];
    if (lt !== rt) return lt - rt;
    return conferenceName(lhs) < conferenceName(rhs) ? -1 : 1;
  });

export function conferenceLogoUrl(
  id: number | null | undefined
): string | undefined {
  if (id == null) return undefined;
  const slug = LOGO_SLUGS[id];
  if (slug === undefined) return undefined;
  return `https://a.espncdn.com/i/teamlogos/ncaa_conf/500/${slug}.png`;
}

/**
 * Whether this conference's championship game takes the standings' top two
 * that season — must never claim top-two about a divisional-era pairing.
 * Every FBS conference has been one-table since 2024 except the Sun Belt
 * (one-table from 2026); Independents have no title game at all.
 */
export function titleGameIsTopTwo(
  id: number | null | undefined,
  year: number
): boolean {
  if (id == null || CONFERENCE_NAMES[id] === undefined || id === 18) {
    return false;
  }
  return year >= (id === 37 ? 2026 : 2024);
}
