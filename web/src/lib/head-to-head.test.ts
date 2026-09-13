import { describe, expect, it } from "vitest";
import type { Game, GameStatus, Team } from "./types";
import type { League } from "./leagues";
import { headToHeadSeasons } from "./leagues";
import {
  leadingSide,
  makeHeadToHead,
  seriesSentence,
  windowLabel,
} from "./head-to-head";

function team(id: string, school: string, league: League = "cfb"): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name: school,
    school,
    abbreviation: school.slice(0, 3).toUpperCase(),
    conferenceId: "8",
    conferenceName: "SEC",
    logoUrl: "",
  };
}

const GEORGIA = team("61", "Georgia");
const ALABAMA = team("333", "Alabama");
const AUBURN = team("2", "Auburn");

function meeting(fields: {
  id: string;
  on?: string;
  home: Team;
  away: Team;
  homeScore?: number | null;
  awayScore?: number | null;
  homeWon?: boolean;
  awayWon?: boolean;
  status?: GameStatus;
  league?: League;
}): Game {
  return {
    id: fields.id,
    league: fields.league ?? "cfb",
    status: fields.status ?? "complete",
    scheduledAt: fields.on ?? "",
    venue: { name: "", city: "", state: "" },
    homeTeam: {
      team: fields.home,
      score: fields.homeScore ?? null,
      isWinner: fields.homeWon,
    },
    awayTeam: {
      team: fields.away,
      score: fields.awayScore ?? null,
      isWinner: fields.awayWon,
    },
    seasonYear: 2025,
    conferenceGame: true,
  };
}

/** The game the series is built for: Georgia away at Alabama, this December. */
function anchor(league: League = "cfb"): Game {
  return meeting({
    id: "anchor",
    on: "2025-12-06T21:00Z",
    home: ALABAMA,
    away: GEORGIA,
    status: "scheduled",
    league,
  });
}

describe("makeHeadToHead", () => {
  it("keeps only completed meetings between the two teams", () => {
    const series = makeHeadToHead(
      [
        meeting({
          id: "1",
          on: "2024-09-28T20:00Z",
          home: GEORGIA,
          away: ALABAMA,
          homeScore: 30,
          awayScore: 41,
        }),
        // A third team: Georgia played it, these two did not.
        meeting({
          id: "2",
          on: "2024-11-16T20:00Z",
          home: GEORGIA,
          away: AUBURN,
          homeScore: 31,
          awayScore: 13,
        }),
        // Never played.
        meeting({
          id: "3",
          on: "2024-10-05T20:00Z",
          home: ALABAMA,
          away: GEORGIA,
          status: "postponed",
        }),
      ],
      anchor(),
      2016
    );

    expect(series.meetings.map((game) => game.id)).toEqual(["1"]);
  });

  it("excludes the anchor game itself", () => {
    const game = anchor();
    const played = { ...game, id: game.id, status: "complete" as const };
    const series = makeHeadToHead([played], game, 2016);
    expect(series.meetings).toHaveLength(0);
  });

  it("excludes meetings after the anchor — a 2019 page is a 2019 series", () => {
    const series = makeHeadToHead(
      [
        meeting({
          id: "before",
          on: "2024-09-28T20:00Z",
          home: GEORGIA,
          away: ALABAMA,
          homeScore: 30,
          awayScore: 41,
        }),
        meeting({
          id: "after",
          on: "2026-09-28T20:00Z",
          home: GEORGIA,
          away: ALABAMA,
          homeScore: 20,
          awayScore: 17,
        }),
      ],
      anchor(),
      2016
    );
    expect(series.meetings.map((game) => game.id)).toEqual(["before"]);
  });

  it("tallies by team, not by which end of the fixture they played from", () => {
    const series = makeHeadToHead(
      [
        // Georgia (the anchor's away side) won at home.
        meeting({
          id: "1",
          on: "2023-09-28T20:00Z",
          home: GEORGIA,
          away: ALABAMA,
          homeScore: 24,
          awayScore: 20,
        }),
        // And won away too.
        meeting({
          id: "2",
          on: "2024-09-28T20:00Z",
          home: ALABAMA,
          away: GEORGIA,
          homeScore: 17,
          awayScore: 41,
        }),
        // Alabama won this one.
        meeting({
          id: "3",
          on: "2022-09-28T20:00Z",
          home: ALABAMA,
          away: GEORGIA,
          homeScore: 33,
          awayScore: 18,
        }),
      ],
      anchor(),
      2016
    );

    expect(series.awayWins).toBe(2); // Georgia
    expect(series.homeWins).toBe(1); // Alabama
    expect(leadingSide(series)).toBe("away");
  });

  it("runs newest first, with undated meetings last", () => {
    const series = makeHeadToHead(
      [
        meeting({
          id: "old",
          on: "2019-09-28T20:00Z",
          home: GEORGIA,
          away: ALABAMA,
          homeScore: 10,
          awayScore: 7,
        }),
        meeting({
          id: "undated",
          home: GEORGIA,
          away: ALABAMA,
          homeScore: 10,
          awayScore: 7,
        }),
        meeting({
          id: "new",
          on: "2024-09-28T20:00Z",
          home: GEORGIA,
          away: ALABAMA,
          homeScore: 10,
          awayScore: 7,
        }),
      ],
      anchor(),
      2016
    );
    expect(series.meetings.map((game) => game.id)).toEqual([
      "new",
      "old",
      "undated",
    ]);
  });

  it("falls back to the winner flag when scores are missing", () => {
    const series = makeHeadToHead(
      [
        meeting({
          id: "1",
          on: "2024-09-28T20:00Z",
          home: ALABAMA,
          away: GEORGIA,
          homeWon: true,
        }),
      ],
      anchor(),
      2016
    );
    expect(series.homeWins).toBe(1);
    expect(series.ties).toBe(0);
  });

  it("counts a draw rather than dropping the game", () => {
    const series = makeHeadToHead(
      [
        meeting({
          id: "1",
          on: "1994-09-28T20:00Z",
          home: ALABAMA,
          away: GEORGIA,
          homeScore: 21,
          awayScore: 21,
        }),
      ],
      anchor(),
      1990
    );
    expect(series.meetings).toHaveLength(1);
    expect(series.ties).toBe(1);
    expect(leadingSide(series)).toBeUndefined();
  });
});

describe("the window caption", () => {
  it("names the season floor, in the league's own spelling", () => {
    expect(windowLabel(makeHeadToHead([], anchor(), 2016))).toBe("Since 2016");
    const nba = anchor("nba");
    expect(windowLabel(makeHeadToHead([], nba, 2024))).toBe("Since 2024-25");
  });

  it("rides the sentence, so a tally is never read as all-time", () => {
    const series = makeHeadToHead(
      [
        meeting({
          id: "1",
          on: "2024-09-28T20:00Z",
          home: ALABAMA,
          away: GEORGIA,
          homeScore: 20,
          awayScore: 41,
        }),
      ],
      anchor(),
      2016
    );
    expect(seriesSentence(series, GEORGIA, ALABAMA)).toBe(
      "Georgia leads 1-0 since 2016"
    );
    expect(seriesSentence(makeHeadToHead([], anchor(), 2016), GEORGIA, ALABAMA)).toBe(
      "No meetings since 2016"
    );
  });
});

describe("how deep the window goes", () => {
  it("follows how often two teams actually meet", () => {
    // Sized in meetings, expressed in seasons: football's leagues play each
    // other once or twice a year, basketball's and hockey's two to four times.
    expect(headToHeadSeasons("cfb")).toBe(10);
    expect(headToHeadSeasons("nfl")).toBe(6);
    expect(headToHeadSeasons("nba")).toBe(3);
    expect(headToHeadSeasons("nhl")).toBe(3);
  });
});
