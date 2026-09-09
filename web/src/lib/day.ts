// The day — the Scores screen's unit of time since the leagues stopped
// sharing a calendar (iOS, 2026-09-05). A port of `DaySlot`/`DayFormat`
// (StatSideShared/Models/Day.swift).
//
// A day is the only unit every league agrees on. College football's "Week 2"
// and the NFL's are different date ranges, and college football's single
// "Bowls" slot swallows four NFL playoff rounds whole — so a week strip can
// only ever be honest about one league at a time.
//
// Every date here is a **local** start-of-day: the strip, the section
// buckets and the persisted expansion ids all speak the user's calendar,
// because "Saturday" means the user's Saturday.

export function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

export function addDays(date: Date, days: number): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
}

/**
 * `"2026-09-05"`, from local components.
 *
 * Stable across time zones and locales — it is a persisted expansion key, a
 * URL parameter and a bucket key, so it comes from date parts rather than a
 * formatter.
 */
export function dayId(date: Date): string {
  const year = String(date.getFullYear()).padStart(4, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * The inverse of `dayId`: a local start-of-day from `"2026-09-05"`.
 *
 * Rejects a day that isn't one rather than rolling it over — `new Date(2026,
 * 12, 1)` is next January and February 31st is March 3rd, and a link that
 * lands the strip on a day nobody meant is worse than one carrying no day at
 * all.
 */
export function dayFromId(id: string): Date | undefined {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(id);
  if (!match) return undefined;
  const [year, month, day] = [
    Number(match[1]),
    Number(match[2]),
    Number(match[3]),
  ];
  const date = new Date(year, month - 1, day);
  if (date.getMonth() !== month - 1 || date.getDate() !== day) return undefined;
  return date;
}

export function isSameDay(a: Date, b: Date): boolean {
  return dayId(a) === dayId(b);
}

/** Whole days from `a` to `b`, both read as local calendar days. */
export function daysBetween(a: Date, b: Date): number {
  const ms = startOfDay(b).getTime() - startOfDay(a).getTime();
  // Round rather than floor: a DST shift makes a "day" 23 or 25 hours long.
  return Math.round(ms / 86_400_000);
}

/** Every day from `start` to `end` inclusive — the strip's contents. */
export function daysInRange(start: Date, end: Date): Date[] {
  const days: Date[] = [];
  for (
    let cursor = startOfDay(start);
    cursor <= end;
    cursor = addDays(cursor, 1)
  ) {
    days.push(cursor);
  }
  return days;
}

export function clampDay(day: Date, start: Date, end: Date): Date {
  const value = startOfDay(day);
  if (value < startOfDay(start)) return startOfDay(start);
  if (value > startOfDay(end)) return startOfDay(end);
  return value;
}

/**
 * What a day chip says.
 *
 * Yesterday and tomorrow get their names beside today's (iOS, 2026-09-06):
 * "Yesterday" is what anyone calls yesterday, and VoiceOver was already
 * saying all three, so the chips just agree with it now.
 *
 * Every other chip carries its **month** — "Sun, Sep 27". The strip spans a
 * whole season that crosses a year boundary, so a bare "Sat 5" stops meaning
 * anything the moment you drag past the fortnight either side of today.
 */
export function dayChipLabel(day: Date, now: Date = new Date()): string {
  switch (daysBetween(now, day)) {
    case 0:
      return "Today";
    case -1:
      return "Yesterday";
    case 1:
      return "Tomorrow";
    default:
      return day.toLocaleDateString("en-US", {
        weekday: "short",
        month: "short",
        day: "numeric",
      });
  }
}

/** The spoken/long form — "Saturday, September 5". */
export function dayLongLabel(day: Date): string {
  return day.toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
  });
}

/** A section header's day — "Saturday, Sep 5". */
export function daySectionTitle(day: Date): string {
  return day.toLocaleDateString("en-US", {
    weekday: "long",
    month: "short",
    day: "numeric",
  });
}

/** The `?day=` spelling, and what it parses back through. */
export const DAY_PARAM = "day";
