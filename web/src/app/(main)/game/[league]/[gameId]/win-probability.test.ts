import { describe, it, expect } from "vitest";
import type { WinProbability } from "@/lib/types";
import {
  winProbabilityReading,
  winProbabilitySplit,
  winProbabilitySpokenLabel,
} from "./win-probability";

const pregame: WinProbability = { kind: "pregame", home: 44.4, away: 55.6 };
const series: WinProbability = {
  kind: "series",
  points: [0.6, 0.72, 0.31, 0.0],
};

describe("winProbabilityReading", () => {
  it("reads the predictor before kickoff, normalised to the pair", () => {
    const reading = winProbabilityReading(pregame, false);
    expect(reading.caption).toBe("ESPN predictor");
    expect(reading.homePercent).toBeCloseTo(44.4);
    // A pair that doesn't sum to 100 still splits to 100.
    expect(
      winProbabilityReading({ kind: "pregame", home: 30, away: 10 }, false)
        .homePercent
    ).toBeCloseTo(75);
  });

  it("reads the latest play while live", () => {
    const reading = winProbabilityReading(series, false);
    expect(reading.caption).toBe("Live");
    expect(reading.homePercent).toBeCloseTo(0);
  });

  it("reads the kickoff value once final, not the 100-0 at the whistle", () => {
    const reading = winProbabilityReading(series, true);
    expect(reading.caption).toBe("At kickoff");
    expect(reading.homePercent).toBeCloseTo(60);
  });

  it("keeps the predictor's caption on a final that never got a series", () => {
    expect(winProbabilityReading(pregame, true).caption).toBe(
      "ESPN predictor"
    );
  });
});

describe("winProbabilitySplit", () => {
  it("rounds home and gives away the remainder", () => {
    expect(
      winProbabilitySplit(winProbabilityReading(pregame, false))
    ).toEqual({ away: 56, home: 44 });
  });
});

describe("winProbabilitySpokenLabel", () => {
  it("names the moment and both sides, away first", () => {
    expect(
      winProbabilitySpokenLabel(series, true, "Liberty", "Coastal Carolina")
    ).toBe(
      "Win probability at kickoff, Liberty 40 percent, Coastal Carolina 60 percent"
    );
    expect(winProbabilitySpokenLabel(series, false, "A", "B")).toBe(
      "Win probability now, A 100 percent, B 0 percent"
    );
    expect(winProbabilitySpokenLabel(pregame, false, "A", "B")).toBe(
      "Win probability, A 56 percent, B 44 percent"
    );
  });
});
