import { describe, expect, it } from "vitest";
import { transformSituation } from "./transformers";
import type { EspnDrive } from "./types";

const AWAY = "61";
const HOME = "333";

function drive(over: Partial<EspnDrive> = {}): EspnDrive {
  return {
    id: "d1",
    description: "1 play, 6 yards, 0:05",
    team: { id: AWAY },
    plays: [
      {
        id: "p1",
        text: "(7:53) Shotgun #20 L.Pulalasi rush middle for 6 yards",
        end: {
          shortDownDistanceText: "2nd & 4",
          possessionText: "WSU 26",
          yardsToEndzone: 74,
        },
      },
    ],
    ...over,
  };
}

describe("the live situation", () => {
  it("is nothing at all without a drive in progress", () => {
    // ESPN drops `drives.current` the moment a game is final, which is what
    // retires the Gamecast strip with no clock check of its own.
    expect(transformSituation(undefined, AWAY)).toBeUndefined();
  });

  it("is nothing without a play to read", () => {
    expect(transformSituation(drive({ plays: [] }), AWAY)).toBeUndefined();
  });

  it("reads the down the play left behind, not the one it began on", () => {
    // The strip describes what happens *next*.
    const situation = transformSituation(drive(), AWAY)!;
    expect(situation.downDistanceText).toBe("2nd & 4");
    expect(situation.possessionText).toBe("WSU 26");
    expect(situation.driveSummary).toBe("1 play, 6 yards, 0:05");
  });

  it("puts the away team's drive at its own end of the bar, moving right", () => {
    // `yardsToEndzone` counts toward the *defence's* end zone, so 74 with the
    // away team on offence is 26 yards from the away goal line.
    const situation = transformSituation(drive(), AWAY)!;
    expect(situation.fieldPosition).toBeCloseTo(0.26);
    expect(situation.drivingRight).toBe(true);
  });

  it("mirrors it for the home team, moving left", () => {
    const situation = transformSituation(
      drive({ team: { id: HOME } }),
      AWAY
    )!;
    expect(situation.fieldPosition).toBeCloseTo(0.74);
    expect(situation.drivingRight).toBe(false);
  });

  it("clamps a spot past the goal line", () => {
    // A payload can hand back a negative distance on a scoring play.
    const scored = transformSituation(
      drive({
        team: { id: HOME },
        plays: [{ id: "p", end: { yardsToEndzone: -3 } }],
      }),
      AWAY
    )!;
    expect(scored.fieldPosition).toBe(0);
  });

  it("leaves the bar off when the payload gave no distance, and stands", () => {
    const situation = transformSituation(
      drive({ plays: [{ id: "p", text: "kneel down", end: {} }] }),
      AWAY
    )!;
    expect(situation.fieldPosition).toBeUndefined();
    expect(situation.lastPlayText).toBe("kneel down");
  });
});
