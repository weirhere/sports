// Week slots — still decoded, no longer navigated by.
//
// The **week-rollover machinery retired with the week strip** (iOS,
// 2026-09-05): `defaultWeekSelection`, its Sunday tie-break and the
// season-year helpers all went, because the day strip left them with zero
// callers. They can't come back unchanged either — a week strip is only ever
// honest about one league at a time, so a future week surface would be
// per-league and re-derived.
//
// What stays is the shape: ESPN still ships `leagues[].calendar` on a plain
// scoreboard request, `Scoreboard.weeks` still carries it, and a football
// league's own pages still group a season by week. The season *clock* lives
// in `@/lib/leagues` now, per league — a college-football rollover would call
// June "next season" while the Stanley Cup was still being played for.

/**
 * One slot in the week strip, parsed from ESPN's calendar. Regular-season
 * slots carry week numbers; postseason slots carry names (Bowls, CFP).
 * Never hardcoded — Week 0 exists some years, CFP ranges shift.
 *
 * Dates stay ISO strings (as ESPN sent them) so slots survive JSON
 * serialization across the server/client boundary.
 */
export interface WeekSlot {
  label: string;
  shortLabel: string;
  /** ESPN season type: 2 regular, 3 postseason. */
  seasonType: number;
  /** ESPN week/slot value, used in scoreboard queries. */
  value: number;
  startDate?: string;
  endDate?: string;
  /** `"${seasonType}-${value}"` — stable across refetches. */
  id: string;
  isPostseason: boolean;
}

export function makeWeekSlot(fields: {
  label: string;
  shortLabel: string;
  seasonType: number;
  value: number;
  startDate?: string;
  endDate?: string;
}): WeekSlot {
  return {
    ...fields,
    id: `${fields.seasonType}-${fields.value}`,
    isPostseason: fields.seasonType === 3,
  };
}
