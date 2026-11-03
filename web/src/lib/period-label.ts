// The period marker the scoring list and the play log both print above a run
// of rows — the web twin of iOS `PeriodLabel`.
//
// What a period is called is the league's: four quarters in football and
// basketball, three periods in hockey. Past regulation every league says
// OVERTIME and then counts, with one exception — **the NHL settles a
// regular-season tie in a shootout after the overtime**, which arrives as
// period 5 (verified live 2026-09-08: `Final/SO`, `altDetail: "SO"`). A
// playoff period 5 is a *second* overtime, so the shootout label is only ever
// offered where the game could actually have one.

import { isBaseball, periodFormat, type League } from "@/lib/leagues";
import { POSTSEASON_SEASON_TYPE } from "@/lib/postseason";
import type { Game } from "@/lib/types";

export function periodText(
  period: number | undefined,
  league: League = "cfb",
  allowsShootout = false
): string {
  if (period === undefined) return "—";
  const format = periodFormat(league);
  // Extra innings are innings (iOS, 2026-11-03).
  if (isBaseball(league)) return `${ordinal(period)} ${format.longName}`;
  if (period <= format.regulationCount) {
    return `${ordinal(period)} ${format.longName}`;
  }
  if (period === format.regulationCount + 1) return "OVERTIME";
  if (allowsShootout && period === format.regulationCount + 2) return "SHOOTOUT";
  return `${period - format.regulationCount}OT`;
}

/** The short form a line-score header and a live clock use: "3", "OT", "SO". */
export function periodShort(
  period: number,
  league: League,
  allowsShootout = false
): string {
  if (isBaseball(league)) return String(period);
  const format = periodFormat(league);
  if (period <= format.regulationCount) return String(period);
  if (period === format.regulationCount + 1) return "OT";
  if (allowsShootout && period === format.regulationCount + 2) return "SO";
  return `${period - format.regulationCount}OT`;
}

/**
 * Whether a period past the overtime would be a shootout rather than a second
 * overtime — hockey's regular season only.
 */
export function allowsShootout(game: Game): boolean {
  return (
    game.league === "nhl" && game.seasonType !== POSTSEASON_SEASON_TYPE
  );
}

/** A half-inning, baseball's plays heading: "TOP 1ST", "BOTTOM 9TH". */
export function halfInningText(period: number | undefined, half: InningHalf): string {
  const word = half.toUpperCase();
  return period === undefined ? word : `${word} ${ordinal(period)}`;
}

export type InningHalf = "top" | "bottom" | "middle" | "end";

function ordinal(n: number): string {
  // Teens are all "TH" — the 11th, 12th and 13th innings exist.
  if ([11, 12, 13].includes(n % 100)) return `${n}TH`;
  switch (n % 10) {
    case 1:
      return `${n}ST`;
    case 2:
      return `${n}ND`;
    case 3:
      return `${n}RD`;
    default:
      return `${n}TH`;
  }
}
