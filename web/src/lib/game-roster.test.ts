// The Roster tab's assembly rules (iOS `GameRosterTests`), against the
// shapes each league actually ships.

import { describe, it, expect } from "vitest";
import {
  factsTabTitle,
  inactiveTitle,
  makeGameRoster,
  makeSide,
  othersTitle,
  rosterPhase,
  shortName,
  sortedByJersey,
  startersSubtitle,
  startersTitle,
  unitGroups,
  type GameRosterPerson,
} from "./game-roster";
import type { BoxScoreTeam, LineupEntry, Team, TeamRoster } from "./types";

const team = (id: string, league: Team["league"]): Team => ({
  id,
  espnId: Number(id),
  league,
  name: "Team",
  school: `Team ${id}`,
  abbreviation: `T${id}`,
  conferenceId: "0",
  conferenceName: "Other",
  logoUrl: "",
});

const roster = (players: { id: string; name: string; jersey?: string; position?: string }[], group = "Offense"): TeamRoster => ({
  coach: { id: "9", name: "Head Coach" },
  groups: [{ name: group, players }],
});

const entry = (overrides: Partial<LineupEntry> & { athleteId: string }): LineupEntry => ({
  isStarter: false,
  didNotPlay: false,
  isScratched: false,
  recordedStat: false,
  ...overrides,
});

describe("makeSide — the game-day roster is the record", () => {
  const nfl = team("34", "nfl");
  const squad = roster([
    { id: "1", name: "Patrick Mahomes", jersey: "15", position: "QB" },
    { id: "2", name: "Travis Kelce", jersey: "87", position: "TE" },
    { id: "3", name: "Harrison Butker", jersey: "7", position: "PK" },
    { id: "4", name: "Backup Guy", jersey: "40", position: "RB" },
    { id: "5", name: "Hurt Guy", jersey: "99", position: "DE" },
  ]);

  it("splits starters, inactives and the rest where the league declares inactives", () => {
    const side = makeSide(
      {
        team: nfl,
        roster: squad,
        lineup: [
          entry({ athleteId: "1", isStarter: true, shortName: "P. Mahomes" }),
          entry({ athleteId: "2", isStarter: true }),
          entry({ athleteId: "3" }),
          entry({ athleteId: "4" }),
          entry({ athleteId: "5", didNotPlay: true }),
        ],
      },
      "played",
      "nfl"
    );
    expect(side.starters.map((p) => p.id)).toEqual(["1", "2"]);
    // The NFL flags inactives, so everyone else dressed and played — in
    // jersey order.
    expect(side.others.map((p) => p.id)).toEqual(["3", "4"]);
    expect(side.inactive.map((p) => p.id)).toEqual(["5"]);
    expect(side.lineupKind).toBe("declared");
    // The roster's full name wins; the game-day short form is kept for the disc.
    expect(side.starters[0]!.name).toBe("Patrick Mahomes");
    expect(side.starters[0]!.shortName).toBe("P. Mahomes");
    expect(side.starters[0]!.unit).toBe("offense");
    expect(side.coach?.name).toBe("Head Coach");
  });

  it("counts only a stat line as having played where nobody is declared inactive", () => {
    const side = makeSide(
      {
        team: team("61", "cfb"),
        roster: squad,
        lineup: [
          entry({ athleteId: "1", isStarter: true }),
          entry({ athleteId: "3", recordedStat: true }),
          entry({ athleteId: "4" }),
        ],
      },
      "played",
      "cfb"
    );
    expect(side.others.map((p) => p.id)).toEqual(["3"]);
    expect(side.inactive).toEqual([]);
  });

  it("before kickoff, a declared lineup is a projection and the whole squad is the roster", () => {
    const side = makeSide(
      {
        team: nfl,
        roster: squad,
        lineup: [entry({ athleteId: "1", isStarter: true }), entry({ athleteId: "3" }), entry({ athleteId: "4" })],
      },
      "upcoming",
      "nfl"
    );
    expect(side.lineupKind).toBe("projected");
    expect(side.others.map((p) => p.id)).toEqual(["3", "4"]);
  });

  it("names an entry the roster never listed from the game-day roster itself", () => {
    const side = makeSide(
      {
        team: nfl,
        lineup: [
          entry({
            athleteId: "77",
            shortName: "E. Greene III",
            jersey: "12",
            isStarter: true,
            position: { abbreviation: "LB", name: "Linebacker" },
          }),
        ],
      },
      "live",
      "nfl"
    );
    const greene = side.starters[0]!;
    expect(greene.name).toBe("E. Greene III");
    expect(greene.jersey).toBe("12");
    expect(greene.position).toBe("LB");
    expect(greene.unit).toBe("defense");
  });

  it("leaves injured names off the bench", () => {
    const side = makeSide(
      {
        team: nfl,
        roster: squad,
        lineup: [
          entry({ athleteId: "1", isStarter: true }),
          entry({ athleteId: "4", recordedStat: true }),
          entry({ athleteId: "5", recordedStat: true }),
        ],
        injuries: [{ id: "5", name: "Hurt Guy", status: "Out" }],
      },
      "live",
      "nfl"
    );
    expect(side.others.map((p) => p.id)).toEqual(["4"]);
    expect(side.injuries).toHaveLength(1);
  });
});

describe("makeSide — the box score as the lineup", () => {
  const nba = team("13", "nba");
  const box: BoxScoreTeam = {
    teamId: "13",
    categories: [
      {
        id: "players",
        label: "Players",
        columns: ["MIN"],
        totals: [],
        players: [
          { id: "1", athleteId: "1", name: "Luka Doncic", jersey: "77", stats: ["36"], isStarter: true, didNotPlay: false, position: "PG" },
          { id: "2", athleteId: "2", name: "Bench Guy", jersey: "5", stats: ["12"], isStarter: false, didNotPlay: false, position: "G" },
          { id: "3", athleteId: "3", name: "Sat Guy", jersey: "30", stats: [""], didNotPlay: true, didNotPlayReason: "Coach's decision" },
          { id: "13-Team", name: "Team", stats: ["240"], didNotPlay: false },
        ],
      },
    ],
  };

  it("reads basketball's starters and DNPs off the box score when there is no game-day roster", () => {
    const side = makeSide({ team: nba, boxScore: box }, "played", "nba");
    expect(side.starters.map((p) => p.id)).toEqual(["1"]);
    expect(side.others.map((p) => p.id)).toEqual(["2"]);
    expect(side.inactive.map((p) => p.id)).toEqual(["3"]);
    expect(side.inactive[0]!.note).toBe("Coach's decision");
    expect(side.lineupKind).toBe("declared");
  });

  it("ignores the box score before kickoff", () => {
    const side = makeSide({ team: nba, boxScore: box }, "upcoming", "nba");
    expect(side.starters).toEqual([]);
    expect(side.others).toEqual([]);
  });
});

describe("makeSide — the depth chart before an NBA or NHL game", () => {
  it("puts rank-1 slots on top in the chart's position and lists the rest of the roster", () => {
    const side = makeSide(
      {
        team: team("13", "nba"),
        roster: roster(
          [
            { id: "1", name: "Luka Doncic", jersey: "77", position: "G" },
            { id: "2", name: "Austin Reaves", jersey: "15", position: "G" },
            { id: "3", name: "Deep Bench", jersey: "44", position: "F" },
          ],
          "Roster"
        ),
        depthChart: [
          { position: "PG", positionName: "Point Guard", rank: 1, athleteId: "1" },
          { position: "PG", rank: 2, athleteId: "2" },
          { position: "SG", rank: 1, athleteId: "2" },
        ],
      },
      "upcoming",
      "nba"
    );
    expect(side.starters.map((p) => [p.id, p.position])).toEqual([
      ["1", "PG"],
      ["2", "SG"],
    ]);
    expect(side.starters[0]!.positionName).toBe("Point Guard");
    expect(side.others.map((p) => p.id)).toEqual(["3"]);
    expect(side.lineupKind).toBe("projected");
  });

  it("keeps injured reserve, suspended and practice squad off the roster list", () => {
    const side = makeSide(
      {
        team: team("34", "nfl"),
        roster: {
          groups: [
            { name: "Offense", players: [{ id: "1", name: "Plays" }] },
            { name: "Practice squad", players: [{ id: "2", name: "Practices" }] },
            { name: "Injured reserve", players: [{ id: "3", name: "Rests" }] },
          ],
        },
      },
      "upcoming",
      "nfl"
    );
    expect(side.others.map((p) => p.id)).toEqual(["1"]);
    expect(side.lineupKind).toBe("none");
  });
});

describe("makeSide — hockey's on-ice lineup", () => {
  it("replaces the starters with the skaters in play while live", () => {
    const side = makeSide(
      {
        team: team("25", "nhl"),
        roster: roster(
          [
            { id: "1", name: "Connor McDavid", jersey: "97", position: "C" },
            { id: "2", name: "Leon Draisaitl", jersey: "29", position: "C" },
            { id: "3", name: "Stuart Skinner", jersey: "74", position: "G" },
          ],
          "Centers"
        ),
        lineup: [entry({ athleteId: "1" }), entry({ athleteId: "2" }), entry({ athleteId: "3", isScratched: true, note: "Scratched" })],
        onIce: ["2"],
      },
      "live",
      "nhl"
    );
    expect(side.starters.map((p) => p.id)).toEqual(["2"]);
    expect(side.lineupKind).toBe("onIce");
    expect(side.others.map((p) => p.id)).toEqual(["1"]);
    expect(side.inactive.map((p) => p.id)).toEqual(["3"]);
    expect(side.inactive[0]!.note).toBe("Scratched");
  });
});

describe("naming", () => {
  const sideWith = (kind: "declared" | "projected" | "onIce" | "none") => ({
    team: team("1", "nfl"),
    starters: [] as GameRosterPerson[],
    others: [],
    inactive: [],
    injuries: [],
    lineupKind: kind,
  });

  it("titles the starters by where they came from", () => {
    expect(startersTitle({ phase: "live", away: sideWith("declared"), home: sideWith("declared") })).toBe("Starters");
    expect(startersTitle({ phase: "upcoming", away: sideWith("projected"), home: sideWith("none") })).toBe("Projected starters");
    expect(startersTitle({ phase: "live", away: sideWith("onIce"), home: sideWith("declared") })).toBe("On the ice");
  });

  it("says once which side is only projected", () => {
    const roster = { phase: "upcoming" as const, away: sideWith("declared"), home: sideWith("projected") };
    expect(startersSubtitle(roster)).toBe("T1 projected");
    expect(startersSubtitle({ ...roster, home: sideWith("declared") })).toBeUndefined();
  });

  it("names the other lists for the phase and the league", () => {
    expect(othersTitle("upcoming")).toBe("Roster");
    expect(othersTitle("live")).toBe("Bench");
    expect(othersTitle("played")).toBe("Also played");
    expect(inactiveTitle("nfl")).toBe("Inactive");
    expect(inactiveTitle("nba")).toBe("Did not play");
    expect(inactiveTitle("nhl")).toBe("Scratched");
  });

  it("maps the game's status to a phase and the first tab's name", () => {
    expect(rosterPhase("scheduled")).toBe("upcoming");
    expect(rosterPhase("halftime")).toBe("live");
    expect(rosterPhase("complete")).toBe("played");
    expect(rosterPhase("postponed")).toBe("played");
    expect(factsTabTitle("scheduled")).toBe("Preview");
    expect(factsTabTitle("in_progress")).toBe("Facts");
    expect(factsTabTitle("postponed")).toBe("Facts");
  });
});

describe("helpers", () => {
  it("shortens a name to its last non-suffix word", () => {
    expect(shortName("Patrick Mahomes")).toBe("Mahomes");
    expect(shortName("Robert Griffin III")).toBe("Griffin");
    expect(shortName("Odell Beckham Jr.")).toBe("Beckham");
    expect(shortName("Cher")).toBe("Cher");
  });

  it("sorts by jersey number, numberless last, otherwise stable", () => {
    const people: GameRosterPerson[] = [
      { id: "a", name: "A", shortName: "A", jersey: "14" },
      { id: "b", name: "B", shortName: "B" },
      { id: "c", name: "C", shortName: "C", jersey: "7" },
      { id: "d", name: "D", shortName: "D" },
    ];
    expect(sortedByJersey(people).map((p) => p.id)).toEqual(["c", "a", "b", "d"]);
  });

  it("groups by unit in football and not elsewhere", () => {
    const qb: GameRosterPerson = { id: "1", name: "QB", shortName: "QB", unit: "offense" };
    const k: GameRosterPerson = { id: "2", name: "K", shortName: "K", unit: "specialTeams" };
    const ath: GameRosterPerson = { id: "3", name: "ATH", shortName: "ATH" };
    const groups = unitGroups([qb, ath], [k], "nfl");
    expect(groups.map((g) => [g.id, g.away.length, g.home.length])).toEqual([
      ["offense", 1, 0],
      ["specialTeams", 0, 1],
      ["other", 1, 0],
    ]);
    // The NBA and NHL have no units: one uncaptioned group, or nothing.
    const guard: GameRosterPerson = { id: "4", name: "G", shortName: "G" };
    expect(unitGroups([guard], [], "nba").map((g) => [g.id, g.unit])).toEqual([["other", undefined]]);
    expect(unitGroups([], [], "nba")).toEqual([]);
  });

  it("builds both sides and reports an empty roster", () => {
    const roster = makeGameRoster("upcoming", "nfl", { team: team("1", "nfl") }, { team: team("2", "nfl") });
    expect(roster.away.starters).toEqual([]);
    expect(roster.phase).toBe("upcoming");
  });
});
