import { describe, expect, it } from "vitest";
import { fillPercent, leagueDestinations } from "./game-info-cards";
import type { ConferenceStandingsGroup, Game, Team } from "@/lib/types";
import type { League } from "@/lib/leagues";

function team(id: string, conferenceId: string, league: League = "cfb"): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name: id,
    school: id,
    abbreviation: id.slice(0, 3),
    conferenceId,
    conferenceName: "",
    logoUrl: "",
  };
}

function game(away: Team, home: Team): Game {
  return {
    id: "g",
    league: home.league,
    status: "scheduled",
    scheduledAt: "2026-09-12T16:00:00Z",
    venue: { name: "", city: "", state: "" },
    homeTeam: { team: home, score: null },
    awayTeam: { team: away, score: null },
    seasonYear: 2026,
    conferenceGame: false,
  };
}

describe("the tables a game counts toward", () => {
  it("leads with the widest page, then each side's conference", () => {
    // College football has no whole-league table, so the division its teams
    // play in is the widest page there is.
    const refs = leagueDestinations(game(team("201", "8"), team("130", "5")));
    expect(refs).toEqual([
      { league: "cfb", id: 80 },
      { league: "cfb", id: 8 },
      { league: "cfb", id: 5 },
    ]);
  });

  it("gives a conference game one conference badge, not two", () => {
    // The badges are the tables this game appears in, and both sides share
    // one.
    const refs = leagueDestinations(game(team("61", "8"), team("57", "8")));
    expect(refs).toEqual([
      { league: "cfb", id: 80 },
      { league: "cfb", id: 8 },
    ]);
  });

  it("walks a pro league's division up to the conference above it", () => {
    // A pro scoreboard ships no group at all, so a team arrives stamped with
    // its *division* from the registry — Buffalo is AFC East, and the badge
    // has to say AFC.
    const refs = leagueDestinations(
      game(team("2", "4", "nfl"), team("12", "6", "nfl"))
    );
    expect(refs[0]).toEqual({ league: "nfl", id: 9 });
    expect(refs).toHaveLength(2); // both AFC — one conference badge
  });

  it("places a side from the page's own standings when the payload ships none", () => {
    // The **summary** payload carries `conferenceId: "0"` on every team
    // (verified live), so without this the row renders nothing at all.
    const standings: ConferenceStandingsGroup[] = [
      {
        id: "8",
        league: "cfb",
        name: "SEC",
        entries: [{ team: team("61", "0") } as never],
      },
    ];
    const refs = leagueDestinations(
      game(team("61", "0"), team("9999", "0")),
      standings
    );
    expect(refs).toEqual([
      { league: "cfb", id: 80 },
      { league: "cfb", id: 8 },
    ]);
  });

  it("renders nothing rather than a dead badge for an unplaceable game", () => {
    expect(leagueDestinations(game(team("1", "0"), team("2", "0")))).toEqual([]);
  });
});

describe("the attendance meter", () => {
  it("reports how full the place was", () => {
    expect(fillPercent(93033, 92746)).toBe(100);
    expect(fillPercent(45000, 90000)).toBe(50);
  });

  it("survives a capacity ESPN never shipped", () => {
    expect(fillPercent(45000, 0)).toBe(0);
  });
});
