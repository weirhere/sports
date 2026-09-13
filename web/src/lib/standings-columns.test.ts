import { describe, expect, it } from "vitest";
import type { ConferenceStanding } from "./types";
import {
  standingSentence,
  standingValue,
  standingsColumns,
  standingsScrollsHorizontally,
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
  it("gives college football a conference record beside the overall", () => {
    expect(standingsColumns("cfb").map((c) => c.caption)).toEqual(["CONF", "OVR"]);
  });

  it("gives the NFL ESPN's own spread, in ESPN's own order", () => {
    expect(standingsColumns("nfl").map((c) => c.caption)).toEqual([
      "W",
      "L",
      "T",
      "PCT",
      "HOME",
      "AWAY",
      "DIV",
      "CONF",
      "PF",
      "PA",
      "DIFF",
      "STRK",
    ]);
    // W, L and T replace the OVR summary rather than sitting beside it:
    // three columns and one string are the same three numbers.
    expect(standingsColumns("nfl").some((c) => c.field === "overallRecord")).toBe(
      false
    );
  });

  it("pins only the table too wide to fit", () => {
    expect(standingsScrollsHorizontally("nfl")).toBe(true);
    for (const league of ["cfb", "nba", "nhl"] as const) {
      expect(standingsScrollsHorizontally(league)).toBe(false);
    }
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

describe("the NFL's wide row", () => {
  const bills = (overrides: Partial<ConferenceStanding> = {}) =>
    entry({
      team: { ...entry().team, league: "nfl", school: "Buffalo" },
      wins: 3,
      losses: 0,
      ties: 0,
      winPercentText: "1.000",
      homeRecord: "2-0",
      awayRecord: "1-0",
      divisionRecord: "0-0",
      conferenceRecord: "2-0",
      pointsFor: 88,
      pointsAgainst: 48,
      pointDifferential: "+40",
      streak: "W3",
      ...overrides,
    });

  it("finds a value for every column it promises", () => {
    for (const column of standingsColumns("nfl")) {
      expect(standingValue(bills(), column), column.caption).toBeDefined();
    }
  });

  it("phrases each column the way its own value means", () => {
    const sentence = standingSentence(bills(), "nfl", 1);
    expect(sentence).toContain("3 wins, 0 losses, 0 ties");
    // Records read "and"; a differential keeps its sign, or "-12" would
    // come out as "12".
    expect(sentence).toContain("2 and 0 at home");
    expect(sentence).toContain("+40 point differential");
    // A streak is spelled out — "W3" runs together in every voice.
    expect(sentence).toContain("won 3 streak");
  });
});
