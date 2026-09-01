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
