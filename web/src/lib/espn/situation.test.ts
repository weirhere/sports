import { describe, expect, it } from "vitest";
import { playText, transformPlays, transformSituation } from "./transformers";
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

  it("strips ESPN's leading clock from the last play, and only that", () => {
    const situation = transformSituation(drive(), AWAY)!;
    expect(situation.lastPlayText).toBe(
      "Shotgun #20 L.Pulalasi rush middle for 6 yards"
    );
    expect(playText("(Shotgun) J.Smith pass")).toBe("(Shotgun) J.Smith pass");
    expect(playText("(0:00)")).toBe("(0:00)");
  });
});

describe("the Gamecast field", () => {
  it("draws the drive from its first snap, the play from its snap, and the line to gain", () => {
    // Away (left end zone) with the ball, driving right: 75 to go at the
    // first snap is the away 25; the last play began at the away 40.
    const situation = transformSituation(
      drive({
        offensivePlays: 3,
        yards: 21,
        plays: [
          { id: "a", start: { yardsToEndzone: 75 }, end: { yardsToEndzone: 70 } },
          {
            id: "b",
            type: { text: "Pass Reception" },
            clock: { displayValue: "7:53" },
            start: { yardsToEndzone: 60, downDistanceText: "2nd & 5 at WSU 40" },
            end: { yardsToEndzone: 54, distance: 10, shortDownDistanceText: "1st & 10" },
          },
        ],
      }),
      AWAY,
      HOME
    )!;
    expect(situation.field).toEqual({
      ball: 46,
      driveStart: 25,
      playStart: 40,
      lineToGain: 56,
      isPass: true,
    });
    expect(situation.driveLine).toBe("3 plays, 21 yds");
    expect(situation.lastPlayDownText).toBe("2nd & 5 at WSU 40");
    expect(situation.lastPlayClock).toBe("7:53");
    expect(situation.lastPlayId).toBe("b");
    expect(situation.result).toBeUndefined();
  });

  it("gives a play that changed hands no arrow", () => {
    const situation = transformSituation(
      drive({
        plays: [
          {
            id: "punt",
            type: { text: "Punt" },
            start: { yardsToEndzone: 60, team: { id: HOME } },
            end: { yardsToEndzone: 80, team: { id: AWAY } },
          },
        ],
      }),
      AWAY,
      HOME
    )!;
    expect(situation.field?.playStart).toBeUndefined();
    expect(situation.field?.driveStart).toBeUndefined();
  });

  it("calls a sack a run, and draws no line to gain on goal to go", () => {
    const situation = transformSituation(
      drive({
        plays: [
          {
            id: "s",
            type: { text: "Sack" },
            start: { yardsToEndzone: 6 },
            end: { yardsToEndzone: 8, distance: 8 },
          },
        ],
      }),
      AWAY,
      HOME
    )!;
    expect(situation.field?.isPass).toBe(false);
    expect(situation.field?.lineToGain).toBeUndefined();
  });

  it("names a touchdown after the touchdown, not the extra point, and credits whose points", () => {
    const previous = [
      { id: "d0", plays: [{ id: "x", awayScore: 0, homeScore: 3 }] },
    ];
    const situation = transformSituation(
      drive({
        isScore: true,
        plays: [
          { id: "td", type: { text: "Passing Touchdown" }, scoringPlay: true, awayScore: 6, homeScore: 3, end: { yardsToEndzone: 0 } },
          { id: "pat", type: { text: "Extra Point Good" }, scoringPlay: true, awayScore: 7, homeScore: 3, end: { yardsToEndzone: 0 } },
        ],
      }),
      AWAY,
      HOME,
      previous
    )!;
    expect(situation.result).toBe("Touchdown");
    expect(situation.resultTeamId).toBe(AWAY);
    expect(situation.field?.lineToGain).toBeUndefined();
  });

  it("credits a pick six to the defense", () => {
    const situation = transformSituation(
      drive({
        plays: [
          {
            id: "pick",
            type: { text: "Interception Return Touchdown" },
            scoringPlay: true,
            awayScore: 0,
            homeScore: 6,
          },
        ],
      }),
      AWAY,
      HOME
    )!;
    expect(situation.resultTeamId).toBe(HOME);
  });
});

describe("the flat feed's spots", () => {
  it("drops ESPN's no-spot sentinel and keeps real coordinates", () => {
    const plays = transformPlays([
      { id: "1", coordinate: { x: 19, y: 12 }, shootingPlay: true },
      { id: "2", coordinate: { x: -214748340, y: -214748340 } },
      { id: "3", strength: { abbreviation: "power-play" } },
    ]);
    expect(plays[0].coordinate).toEqual({ x: 19, y: 12 });
    expect(plays[0].isShootingPlay).toBe(true);
    expect(plays[1].coordinate).toBeUndefined();
    expect(plays[2].strength).toBe("power-play");
  });

  it("measures a punted drive's leftovers against the team that has the ball", () => {
    // Live, NFL 2026-09-27: ARI (away) punted; `drives.current` stayed ARI's
    // while its last play, a timeout, was SF's with a start of 0.
    const situation = transformSituation(
      drive({
        team: { id: AWAY },
        plays: [
          { id: "snap", start: { yardsToEndzone: 75, team: { id: AWAY } }, end: { yardsToEndzone: 70, team: { id: AWAY } } },
          {
            id: "timeout",
            type: { text: "Official Timeout" },
            start: { yardsToEndzone: 0, team: { id: HOME } },
            end: { yardsToEndzone: 86, distance: 10, possessionText: "SF 14", team: { id: HOME } },
          },
        ],
      }),
      AWAY,
      HOME
    )!;
    expect(situation.possessionTeamId).toBe(HOME);
    expect(situation.drivingRight).toBe(false);
    expect(situation.field).toEqual({
      ball: 86,
      driveStart: undefined,
      playStart: undefined,
      lineToGain: 76,
      isPass: false,
    });
  });

  it("gives a timeout mid-drive no arrow", () => {
    const situation = transformSituation(
      drive({
        plays: [
          { id: "snap", start: { yardsToEndzone: 75 }, end: { yardsToEndzone: 70 } },
          { id: "to", type: { text: "Timeout" }, start: { yardsToEndzone: 0 }, end: { yardsToEndzone: 70 } },
        ],
      }),
      AWAY,
      HOME
    )!;
    expect(situation.field?.playStart).toBeUndefined();
    expect(situation.field?.driveStart).toBe(25);
  });
});
