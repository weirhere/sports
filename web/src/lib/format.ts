// Live-status formatting — a faithful port of the iOS app's
// `GameStatus.liveStatusText` / `periodLabel` (StatSideShared/Models/Game.swift).
// THE single live formatter: every surface renders through it so "Q2 0:00"
// can never reappear where the rest of the world says "Half".

export type LivePhase = "playing" | "halftime" | "endOfPeriod";

export function periodLabel(period: number): string {
  if (period <= 4) return `Q${period}`;
  return period === 5 ? "OT" : `${period - 4}OT`;
}

export interface LiveStatusInput {
  /** Where the live clock cycle stands; defaults to "playing". */
  livePhase?: LivePhase;
  /** Current period (1–4, 5 = OT, 6 = 2OT, …). */
  quarter?: number;
  /** Display clock, e.g. "5:24". */
  clock?: string;
  /** ESPN's detail string — the degrade path when parts are missing. */
  detail?: string;
}

/**
 * The live status line — "Q3 5:24", "Half", "End Q1", "OT 0:48" — for a
 * game that is in progress. Callers supply their own fallback for the rare
 * live game with nothing to say (`?? "Live"`).
 */
// --- Kickoff formatting (the iOS `GameRow.relativeKickParts` ladder) ---

/** "3:30 PM" in the viewer's locale/timezone. */
export function formatKickTime(date: Date): string {
  return date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
  });
}

export interface RelativeKickOptions {
  /** ESPN's placeholder clock — keep the day, swap the time for "TBD". */
  timeTBD?: boolean;
  /** "long" weekdays for spoken sentences; "short" (default) on screen. */
  weekday?: "short" | "long";
  /** Injected so the Today/Tomorrow thresholds are testable. */
  now?: Date;
}

/**
 * How much of the date a kickoff spends: "Today"/"Tomorrow" inside the 48
 * hours that matter, weekday + date ("Sat, 9/5") past that — a bare "Sat"
 * only ever means *this* Saturday, so it would lie about a game three weeks
 * out. Day and time come back separately because the status column gives
 * them a line each; flowing contexts join them via `relativeKick`.
 */
export function relativeKickParts(
  date: Date,
  options: RelativeKickOptions = {}
): { day: string; time: string } {
  const now = options.now ?? new Date();
  const time = options.timeTBD ? "TBD" : formatKickTime(date);
  const startOfDay = (d: Date) =>
    new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const days = Math.round(
    (startOfDay(date) - startOfDay(now)) / (24 * 60 * 60 * 1000)
  );
  if (days === 0) return { day: "Today", time };
  if (days === 1) return { day: "Tomorrow", time };
  return {
    day: date.toLocaleDateString("en-US", {
      weekday: options.weekday ?? "short",
      month: "numeric",
      day: "numeric",
    }),
    time,
  };
}

/** The parts as one phrase — "Sat, 9/5 3:30 PM". */
export function relativeKick(
  date: Date,
  options: RelativeKickOptions = {}
): string {
  const parts = relativeKickParts(date, options);
  return `${parts.day} ${parts.time}`;
}

export function liveStatusText(input: LiveStatusInput): string | undefined {
  const phase = input.livePhase ?? "playing";
  switch (phase) {
    case "halftime":
      return "Half";
    case "endOfPeriod":
      // The clock has run out, so "Q2 0:00" would claim a running clock;
      // the period alone carries the truth.
      return input.quarter !== undefined
        ? `End ${periodLabel(input.quarter)}`
        : input.detail;
    case "playing": {
      const parts: string[] = [];
      if (input.quarter !== undefined) parts.push(periodLabel(input.quarter));
      if (input.clock) parts.push(input.clock);
      const line = parts.join(" ");
      return line.length > 0 ? line : input.detail;
    }
  }
}

// --- Unannounced kickoffs ----------------------------------------------

/**
 * ESPN parks a game whose kickoff hasn't been announced at **midnight
 * Eastern** and flags it `timeValid: false`. Midnight Eastern is the
 * *previous* calendar day everywhere west of it, so a raw parse files every
 * TBD game a day early for Central, Mountain, Pacific, Alaska and Hawaii —
 * four of the six US zones.
 *
 * The day is the only real thing in the value, so it is what survives: read
 * the Eastern day, rebuild it as **local midnight**. Midnight rather than
 * noon so a TBD game keeps sorting first within its day.
 *
 * Applied at the mapping boundary, not at the bucket: a game's date is read
 * by the day strip, a row's day line, team schedules, shares and links
 * alike, so one normalization beats six.
 *
 * Announced kickoffs are untouched — of the 30 real kickoffs in the window
 * this was reproduced against, none differ between the Eastern and Central
 * day, so the sentinel was the whole bug.
 */
export function placeholderKickoff(date: Date): Date {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const value = (type: string) =>
    Number(parts.find((part) => part.type === type)?.value);
  const [year, month, day] = [value("year"), value("month"), value("day")];
  if (![year, month, day].every(Number.isFinite)) return date;
  return new Date(year, month - 1, day);
}

/**
 * A kickoff instant as the app should hold it: re-anchored when ESPN's
 * payload says the time is a placeholder, verbatim otherwise.
 */
export function parseKickoff(
  iso: string | undefined,
  timeTBD: boolean
): string {
  if (!iso) return "";
  if (!timeTBD) return iso;
  const parsed = new Date(iso);
  if (Number.isNaN(parsed.getTime())) return iso;
  return placeholderKickoff(parsed).toISOString();
}
