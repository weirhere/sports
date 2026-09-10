import { describe, expect, it } from "vitest";
import type { ConferenceStanding } from "./types";
import {
  standingSentence,
  standingValue,
  standingsColumns,
} from "./standings-columns";

function entry(overrides: Partial<ConferenceStanding> = {}): ConferenceStanding {
  return {
    team: {
      id: "1",
      espnId: 1,
      league: "nhl",
      name: "",
      school: "Carolina",
      abbreviation: "CAR",
      conferenceId: "0",
      conferenceName: "",
      logoUrl: "",
    },
    conferenceWins: 0,
    conferenceLosses: 0,
    overallWins: 0,
    overallLosses: 0,
    conferenceRank: 1,
    ...overrides,
  };
}

describe("the leagues disagree about what a standing is", () => {
  it("gives football a conference record beside the overall", () => {
    expect(standingsColumns("cfb").map((c) => c.caption)).toEqual(["CONF", "OVR"]);
    expect(standingsColumns("nfl").map((c) => c.caption)).toEqual(["CONF", "OVR"]);
  });

  it("gives the NBA win percentage and games back", () => {
    expect(standingsColumns("nba").map((c) => c.caption)).toEqual([
      "W-L",
      "PCT",
      "GB",
    ]);
  });

  it("gives the NHL games played, a three-part record, and points", () => {
    // No CONF column: the NHL ships no `vsconf` at all, so it would be a
    // permanent dash under a caption promising a number.
    expect(standingsColumns("nhl").map((c) => c.caption)).toEqual([
      "GP",
      "W-L-OTL",
      "PTS",
    ]);
    expect(standingsColumns("nhl").some((c) => c.caption === "CONF")).toBe(false);
  });
});

describe("column values", () => {
  it("drops the zero from a win percentage, the way every basketball table does", () => {
    const pct = standingsColumns("nba").find((c) => c.field === "winPercent")!;
    expect(standingValue(entry({ winPercentText: ".683" }), pct)).toBe(".683");
    // Composed when ESPN ships only the number.
    expect(standingValue(entry({ winPercent: 0.683 }), pct)).toBe(".683");
  });

  it("drops the number, not the row, when the payload didn't carry it", () => {
    const gb = standingsColumns("nba").find((c) => c.field === "gamesBehind")!;
    expect(standingValue(entry(), gb)).toBeUndefined();
  });
});

describe("the row's spoken sentence", () => {
  it("names hockey's three numbers instead of reading them as a string of ands", () => {
    expect(
      standingSentence(
        entry({ gamesPlayed: 82, overallRecord: "53-22-7", points: 113 }),
        "nhl",
        1
      )
    ).toBe("1. Carolina, 82 games played, 53 wins, 22 losses, 7 overtime losses, 113 points");
  });

  it("skips the leader's empty games-back", () => {
    // "-" is ESPN's own "no games back", which reads as nothing at all.
    const sentence = standingSentence(
      entry({ overallRecord: "56-26", winPercentText: ".683", gamesBehind: "-" }),
      "nba",
      1
    );
    expect(sentence).toBe("1. Carolina, 56 and 26 overall, .683 win percentage");
  });
});
