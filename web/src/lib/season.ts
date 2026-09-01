// Season and week-slot logic — a faithful port of the iOS app's `CFBSeason`
// and `WeekLogic` (StatSideShared/Models/CFBSeason.swift, Week.swift).

/**
 * The college football season a date belongs to. January belongs to the
 * previous season (bowls/CFP); from February the upcoming season is the one
 * that matters.
 */
export function cfbSeasonYear(now: Date = new Date()): number {
  const year = now.getFullYear();
  return now.getMonth() === 0 ? year - 1 : year;
}

/** Selectable seasons, newest first, down to the 2014 CFP-era floor. */
export function seasonYears(now: Date = new Date()): number[] {
  const current = cfbSeasonYear(now);
  const years: number[] = [];
  for (let year = current; year >= 2014; year -= 1) {
    years.push(year);
  }
  return years;
}

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

function parseSlotDate(value: string | undefined): Date | undefined {
  if (!value) return undefined;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date;
}

export function weekSlotContains(slot: WeekSlot, date: Date): boolean {
  const start = parseSlotDate(slot.startDate);
  const end = parseSlotDate(slot.endDate);
  if (!start || !end) return false;
  return date >= start && date < end;
}

/**
 * The strip's default selection — a line-for-line port of the iOS
 * `WeekLogic.defaultSelection`. ESPN's current week wins, except on
 * Sundays: Sunday is catch-up + poll day, so we pin to the week whose
 * Saturday just finished (the slot containing yesterday) even if ESPN has
 * already flipped forward. Rolls over Monday morning.
 */
export function defaultWeekSelection(
  slots: WeekSlot[],
  currentWeekNumber: number | undefined,
  currentSeasonType: number | undefined,
  today: Date = new Date()
): WeekSlot | undefined {
  if (slots.length === 0) return undefined;
  if (today.getDay() === 0) {
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    // The Bowls and CFP slots overlap for the whole playoff (Dec 18 → Jan
    // 28 both sit inside Bowls' range), so several slots can contain
    // yesterday. ESPN's current slot breaks the tie when it qualifies;
    // first-containing keeps the September behavior, where ESPN's
    // flipped-forward week never contains yesterday.
    const containing = slots.filter((slot) => weekSlotContains(slot, yesterday));
    if (currentSeasonType !== undefined && currentWeekNumber !== undefined) {
      const current = containing.find(
        (slot) =>
          slot.seasonType === currentSeasonType &&
          slot.value === currentWeekNumber
      );
      if (current) return current;
    }
    if (containing.length > 0) return containing[0];
  }
  if (currentSeasonType !== undefined && currentWeekNumber !== undefined) {
    const slot = slots.find(
      (s) => s.seasonType === currentSeasonType && s.value === currentWeekNumber
    );
    if (slot) return slot;
  }
  const containingToday = slots.find((slot) => weekSlotContains(slot, today));
  if (containingToday) return containingToday;
  const first = slots[0];
  const firstStart = parseSlotDate(first.startDate);
  if (firstStart && today < firstStart) return first;
  return slots[slots.length - 1];
}
