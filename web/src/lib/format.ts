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
