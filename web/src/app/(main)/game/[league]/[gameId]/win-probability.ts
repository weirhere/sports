// Which win-probability number the card shows, and what it's called — the
// pure half of iOS `WinProbabilityCard.reading` and its spoken label.
//
// The number depends on the moment, and the header's trailing caption says
// which:
// - before kickoff, ESPN's matchup predictor;
// - live, the latest per-play value;
// - final, the value at kickoff. The live value at the whistle is always
//   100–0, which says nothing; the kickoff value is what an upset was
//   measured against.

import type { WinProbability } from "@/lib/types";

export type WinProbabilityCaption = "ESPN predictor" | "Live" | "At kickoff";

export interface WinProbabilityReading {
  /** The home side's chance for this moment, in percent. */
  homePercent: number;
  caption: WinProbabilityCaption;
}

export function winProbabilityReading(
  probability: WinProbability,
  isFinal: boolean
): WinProbabilityReading {
  if (probability.kind === "pregame") {
    return {
      homePercent:
        (probability.home / (probability.home + probability.away)) * 100,
      caption: "ESPN predictor",
    };
  }
  const { points } = probability;
  const point = (isFinal ? points[0] : points[points.length - 1]) ?? 0.5;
  return { homePercent: point * 100, caption: isFinal ? "At kickoff" : "Live" };
}

/** Both sides as whole percentages that add to 100. */
export function winProbabilitySplit(reading: WinProbabilityReading): {
  away: number;
  home: number;
} {
  const home = Math.round(reading.homePercent);
  return { away: 100 - home, home };
}

/**
 * "Win probability at kickoff, Liberty 56 percent, Coastal Carolina 44
 * percent." The caption rides in the sentence, lowercased; the predictor
 * needs no qualifier.
 */
export function winProbabilitySpokenLabel(
  probability: WinProbability,
  isFinal: boolean,
  awayName: string,
  homeName: string
): string {
  const reading = winProbabilityReading(probability, isFinal);
  const { away, home } = winProbabilitySplit(reading);
  const moment =
    reading.caption === "At kickoff"
      ? " at kickoff"
      : reading.caption === "Live"
        ? " now"
        : "";
  return `Win probability${moment}, ${awayName} ${away} percent, ${homeName} ${home} percent`;
}
