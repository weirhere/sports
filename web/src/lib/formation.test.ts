// The formation layout (iOS `FormationTests`): rows from the line of
// engagement outward, placement by position abbreviation.

import { describe, it, expect } from "vitest";
import { makeFormation, rowPlayers, unitFor } from "./formation";
import type { GameRosterPerson } from "./game-roster";

const person = (id: string, position: string, league: "nfl" | "nba" | "nhl" = "nfl"): GameRosterPerson => ({
  id,
  name: id,
  shortName: id,
  position,
  unit: unitFor(position, league),
});

const ids = (people: GameRosterPerson[]) => people.map((p) => p.id);

describe("football", () => {
  const offense = [
    person("LT", "LT"), person("LG", "LG"), person("C", "C"), person("RG", "RG"), person("RT", "RT"),
    person("WR1", "WR"), person("WR2", "WR"), person("WR3", "WR"), person("TE", "TE"),
    person("QB", "QB"), person("RB", "RB"),
  ];
  const defense = [
    person("LDE", "DE"), person("DT1", "DT"), person("DT2", "DT"), person("RDE", "DE"),
    person("OLB1", "OLB"), person("MLB", "MLB"), person("OLB2", "OLB"),
    person("CB1", "CB"), person("CB2", "CB"), person("FS", "FS"), person("SS", "SS"),
  ];

  it("draws one platoon: the line on the ball, the wings beside it, the quarterback, the backs", () => {
    const formation = makeFormation([...offense, ...defense], "nfl", "offense");
    expect(formation.rows).toHaveLength(4);
    const [front, wings, qb, backs] = formation.rows;
    expect(front!.kind).toBe("line");
    expect(ids(rowPlayers(front!))).toEqual(["LT", "LG", "C", "RG", "RT"]);
    expect(wings!.kind).toBe("wings");
    if (wings!.kind === "wings") {
      // Two wideouts left, outward; the tight end right beside the tackle,
      // then the third wideout outside him.
      expect(ids(wings!.left)).toEqual(["WR3", "WR1"]);
      expect(ids(wings!.right)).toEqual(["TE", "WR2"]);
    }
    expect(ids(rowPlayers(qb!))).toEqual(["QB"]);
    expect(ids(rowPlayers(backs!))).toEqual(["RB"]);
    expect(formation.unplaced).toEqual([]);
  });

  it("draws the defense with the corners as wings and the safeties deep", () => {
    const formation = makeFormation([...offense, ...defense], "nfl", "defense");
    const [front, backers, corners, deep] = formation.rows;
    expect(ids(rowPlayers(front!))).toEqual(["LDE", "DT1", "DT2", "RDE"]);
    expect(ids(rowPlayers(backers!))).toEqual(["OLB1", "MLB", "OLB2"]);
    expect(corners!.kind).toBe("wings");
    expect(ids(rowPlayers(corners!))).toEqual(["CB1", "CB2"]);
    expect(ids(rowPlayers(deep!))).toEqual(["FS", "SS"]);
  });

  it("lists a starter the table can't place rather than dropping him", () => {
    const formation = makeFormation([person("ATH", "ATH"), person("QB", "QB")], "nfl", "offense");
    expect(ids(formation.unplaced)).toEqual(["ATH"]);
    expect(ids(rowPlayers(formation.rows[0]!))).toEqual(["QB"]);
  });

  it("sends specific sides to their side and generic tackles to the shorter one", () => {
    const formation = makeFormation(
      [person("RT", "RT"), person("OT", "OT"), person("G1", "G"), person("G2", "G"), person("C", "C")],
      "nfl",
      "offense"
    );
    expect(ids(rowPlayers(formation.rows[0]!))).toEqual(["OT", "G1", "C", "G2", "RT"]);
  });

  it("maps ESPN's unit-as-position codes to their unit and draws them nowhere", () => {
    expect(unitFor("OFF", "nfl")).toBe("offense");
    expect(unitFor("DEF", "cfb")).toBe("defense");
    expect(unitFor("ST", "nfl")).toBe("specialTeams");
    expect(unitFor("QB", "nba")).toBeUndefined();
    const formation = makeFormation([person("X", "OFF")], "nfl", "offense");
    expect(formation.rows).toEqual([]);
    expect(ids(formation.unplaced)).toEqual(["X"]);
  });
});

describe("basketball", () => {
  it("puts the guards nearest half court and the center between the forwards", () => {
    const formation = makeFormation(
      [person("C", "C", "nba"), person("PF", "PF", "nba"), person("SF", "SF", "nba"), person("SG", "SG", "nba"), person("PG", "PG", "nba")],
      "nba"
    );
    expect(formation.rows.map((row) => ids(rowPlayers(row)))).toEqual([
      ["PG", "SG"],
      ["SF", "C", "PF"],
    ]);
  });

  it("alternates generic guards and forwards", () => {
    const formation = makeFormation(
      [person("G1", "G", "nba"), person("G2", "G", "nba"), person("F1", "F", "nba"), person("F2", "F", "nba"), person("C", "C", "nba")],
      "nba"
    );
    expect(formation.rows.map((row) => ids(rowPlayers(row)))).toEqual([
      ["G1", "G2"],
      ["F1", "C", "F2"],
    ]);
  });
});

describe("hockey", () => {
  it("draws the forward line, the pairing and the goalie", () => {
    const formation = makeFormation(
      [person("G", "G", "nhl"), person("RD", "RD", "nhl"), person("LD", "LD", "nhl"), person("RW", "RW", "nhl"), person("C", "C", "nhl"), person("LW", "LW", "nhl")],
      "nhl"
    );
    expect(formation.rows.map((row) => ids(rowPlayers(row)))).toEqual([
      ["LW", "C", "RW"],
      ["LD", "RD"],
      ["G"],
    ]);
  });
});
