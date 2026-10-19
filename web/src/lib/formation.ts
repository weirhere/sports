// A lineup arranged on its playing surface — the web twin of iOS
// `Formation` (StatSideShared/Models/Formation.swift, E29, 2026-10-18):
// rows of players from the line of engagement outward, so the field can put
// one team's rows above the midline and the other's below it and have the
// two face each other.
//
// Football is the hard one and the reason this exists (Andy, 2026-10-18:
// "it's hard when during the game the lineup is drastically changing whether
// offense or defense is on the field"). The answer is to draw what a snap
// looks like: one side's offense across the line from the other side's
// defense, eleven on eleven, and let the card flip which team has the ball.
// So `makeFormation` takes a `unit` in football and arranges only that
// platoon; a basketball or hockey lineup is one unit and the parameter is
// ignored.
//
// Placement is by position abbreviation, read off the team roster where it
// has one and ESPN's position table otherwise. Specific sides ("LT", "RCB")
// go to their side; generic ones ("OT", "CB") alternate; anything the layout
// can't name is returned in `unplaced` and listed under the field rather
// than dropped. The arrangement is a picture of who is in, not a scouting
// report — a tackle drawn on the wrong side is still the right tackle.

import type { League } from "@/lib/leagues";
import type { GameRosterPerson, GameRosterUnit } from "@/lib/game-roster";

/**
 * One row of the half. A `line` shares the row's width evenly; `wings` are
 * the players who line up wide of everyone else — receivers and tight ends
 * off the ball, cornerbacks — pinned to the two edges with the middle left
 * open. Nine across one row left every name too small to read (Andy,
 * 2026-10-18), and splitting the wings out is what a real formation does
 * anyway: only seven have to be on the line.
 */
export type FormationRow =
  | { kind: "line"; players: GameRosterPerson[] }
  | { kind: "wings"; left: GameRosterPerson[]; right: GameRosterPerson[] };

export interface Formation {
  /** Row 0 sits on the midline; the last row is deepest in the half. Empty
   *  rows are already dropped. */
  rows: FormationRow[];
  /** Starters with no position the layout knows. */
  unplaced: GameRosterPerson[];
}

export function rowPlayers(row: FormationRow): GameRosterPerson[] {
  return row.kind === "line" ? row.players : [...row.left, ...row.right];
}

export function formationIsEmpty(formation: Formation): boolean {
  return formation.rows.every((row) => rowPlayers(row).length === 0);
}

export function isFootball(league: League): boolean {
  return league === "cfb" || league === "nfl";
}

/**
 * ESPN's football position abbreviations, by where they line up. Both the
 * team roster's spellings ("OT", "G", "S") and the game-day roster's table
 * are covered. "OFF", "DEF" and "ST" are ESPN's own unit-as-position codes:
 * a player listed that way names his unit and nothing more, so he is grouped
 * with it and drawn nowhere.
 */
export const FOOTBALL_POSITIONS = (() => {
  const receivers = new Set(["WR", "FL", "SE"]);
  const line = new Set(["LT", "LG", "C", "RG", "RT", "OT", "OG", "OL", "G", "T"]);
  const guardsAndCenters = new Set(["LG", "C", "RG", "OG", "G", "OL"]);
  const backs = new Set(["RB", "FB", "HB", "TB", "LHB", "RHB", "B"]);
  const offense = new Set([...receivers, ...line, ...backs, "TE", "QB", "OFF"]);
  const defensiveEnds = new Set(["LDE", "RDE", "DE", "EDGE"]);
  const defensiveLine = new Set([
    ...defensiveEnds,
    "LDT", "RDT", "DT", "NT", "NG", "MG", "UT", "DL",
  ]);
  const outsideLinebackers = new Set(["LOLB", "ROLB", "OLB", "WLB", "SLB", "LLB", "RLB"]);
  const linebackers = new Set([...outsideLinebackers, "LILB", "RILB", "ILB", "MLB", "LB"]);
  const cornerbacks = new Set(["LCB", "RCB", "CB", "NB", "DB"]);
  const safeties = new Set(["FS", "SS", "S", "LSF", "RSF"]);
  const defense = new Set([
    ...defensiveLine, ...linebackers, ...cornerbacks, ...safeties, "DEF",
  ]);
  const specialTeams = new Set(["PK", "K", "P", "LS", "KR", "PR", "H", "ST"]);
  return {
    receivers, line, guardsAndCenters, backs, offense,
    defensiveEnds, defensiveLine, outsideLinebackers, linebackers,
    cornerbacks, safeties, defense, specialTeams,
  };
})();

/** Football's platoon for a position, undefined for the other leagues and
 *  for a position the table doesn't know. */
export function unitFor(
  position: string | undefined,
  league: League
): GameRosterUnit | undefined {
  if (!isFootball(league) || !position) return undefined;
  const code = position.toUpperCase();
  if (FOOTBALL_POSITIONS.offense.has(code)) return "offense";
  if (FOOTBALL_POSITIONS.defense.has(code)) return "defense";
  if (FOOTBALL_POSITIONS.specialTeams.has(code)) return "specialTeams";
  return undefined;
}

export function makeFormation(
  starters: GameRosterPerson[],
  league: League,
  unit?: GameRosterUnit
): Formation {
  switch (league) {
    case "cfb":
    case "nfl":
      return football(starters, unit ?? "offense");
    case "nba":
      return basketball(starters);
    case "nhl":
      return hockey(starters);
  }
}

function build(rows: FormationRow[], unplaced: GameRosterPerson[]): Formation {
  return {
    rows: rows.filter((row) => rowPlayers(row).length > 0),
    unplaced,
  };
}

const code = (person: GameRosterPerson) => person.position?.toUpperCase() ?? "";

// --- Football ---

function football(starters: GameRosterPerson[], unit: GameRosterUnit): Formation {
  const P = FOOTBALL_POSITIONS;
  // A starter the table can't place belongs to neither picture, so he's
  // listed under whichever is showing.
  const unplaced = starters.filter((person) => person.unit === undefined);
  const mine = starters.filter((person) => person.unit === unit);
  switch (unit) {
    case "offense": {
      const receivers: GameRosterPerson[] = [];
      const tightEnds: GameRosterPerson[] = [];
      const line: GameRosterPerson[] = [];
      const quarterbacks: GameRosterPerson[] = [];
      const backs: GameRosterPerson[] = [];
      for (const person of mine) {
        const c = code(person);
        if (P.receivers.has(c)) receivers.push(person);
        else if (c === "TE") tightEnds.push(person);
        else if (P.line.has(c)) line.push(person);
        else if (c === "QB") quarterbacks.push(person);
        else if (P.backs.has(c)) backs.push(person);
        else unplaced.push(person);
      }
      // Wideouts alternate out from the left; tight ends from the right, so
      // a one-TE set puts him beside the right tackle.
      const wide = split(receivers, [], [], P.receivers, true);
      const ends = split(tightEnds, [], [], new Set(["TE"]), false);
      const interior = arrange(
        line.filter((p) => P.guardsAndCenters.has(code(p))),
        ["LG"], ["C", "OL"], ["RG"], new Set(["G", "OG"])
      );
      const tackles = split(
        line.filter((p) => !P.guardsAndCenters.has(code(p))),
        ["LT"], ["RT"], new Set(["OT", "T"]), true
      );
      const front = [...tackles.left, ...interior, ...tackles.right];
      return build(
        [
          { kind: "line", players: front },
          { kind: "wings", left: [...wide.left, ...ends.left], right: [...ends.right, ...wide.right] },
          { kind: "line", players: quarterbacks },
          { kind: "line", players: backs },
        ],
        unplaced
      );
    }
    case "defense": {
      const linemen: GameRosterPerson[] = [];
      const linebackers: GameRosterPerson[] = [];
      const corners: GameRosterPerson[] = [];
      const safeties: GameRosterPerson[] = [];
      for (const person of mine) {
        const c = code(person);
        if (P.defensiveLine.has(c)) linemen.push(person);
        else if (P.linebackers.has(c)) linebackers.push(person);
        else if (P.cornerbacks.has(c)) corners.push(person);
        else if (P.safeties.has(c)) safeties.push(person);
        else unplaced.push(person);
      }
      const ends = split(
        linemen.filter((p) => P.defensiveEnds.has(code(p))),
        ["LDE"], ["RDE"], new Set(["DE", "EDGE"]), true
      );
      const inside = arrange(
        linemen.filter((p) => !P.defensiveEnds.has(code(p))),
        ["LDT"], ["NT", "NG", "MG", "UT", "DL"], ["RDT"], new Set(["DT"])
      );
      const front = [...ends.left, ...inside, ...ends.right];
      const outside = split(
        linebackers.filter((p) => P.outsideLinebackers.has(code(p))),
        ["LOLB", "WLB", "LLB"], ["ROLB", "SLB", "RLB"], new Set(["OLB"]), true
      );
      const middleBackers = arrange(
        linebackers.filter((p) => !P.outsideLinebackers.has(code(p))),
        ["LILB"], ["MLB"], ["RILB"], new Set(["ILB", "LB"])
      );
      const cornerSplit = split(corners, ["LCB"], ["RCB", "NB"], new Set(["CB", "DB"]), true);
      const backers = [...outside.left, ...middleBackers, ...outside.right];
      const deep = arrange(safeties, ["FS", "LSF"], [], ["SS", "RSF"], new Set(["S"]));
      return build(
        [
          { kind: "line", players: front },
          { kind: "line", players: backers },
          { kind: "wings", left: cornerSplit.left, right: cornerSplit.right },
          { kind: "line", players: deep },
        ],
        unplaced
      );
    }
    case "specialTeams":
      return build([{ kind: "line", players: mine }], unplaced);
  }
}

// --- Basketball ---

function basketball(starters: GameRosterPerson[]): Formation {
  const guards: GameRosterPerson[] = [];
  const frontcourt: GameRosterPerson[] = [];
  const unplaced: GameRosterPerson[] = [];
  for (const person of starters) {
    switch (code(person)) {
      case "PG": case "SG": case "G":
        guards.push(person);
        break;
      case "SF": case "PF": case "F": case "GF": case "C": case "FC":
        frontcourt.push(person);
        break;
      default:
        unplaced.push(person);
    }
  }
  // Guards nearest half court, the center between the forwards.
  const backcourt = arrange(guards, ["PG"], [], ["SG"], new Set(["G"]));
  const front = arrange(frontcourt, ["SF"], ["C", "FC"], ["PF"], new Set(["F", "GF"]));
  return build(
    [
      { kind: "line", players: backcourt },
      { kind: "line", players: front },
    ],
    unplaced
  );
}

// --- Hockey ---

function hockey(starters: GameRosterPerson[]): Formation {
  const forwards: GameRosterPerson[] = [];
  const defense: GameRosterPerson[] = [];
  const goalies: GameRosterPerson[] = [];
  const unplaced: GameRosterPerson[] = [];
  for (const person of starters) {
    switch (code(person)) {
      case "LW": case "C": case "RW": case "W": case "F":
        forwards.push(person);
        break;
      case "LD": case "RD": case "D":
        defense.push(person);
        break;
      case "G":
        goalies.push(person);
        break;
      default:
        unplaced.push(person);
    }
  }
  const line = arrange(forwards, ["LW"], ["C", "F"], ["RW"], new Set(["W"]));
  const pairing = arrange(defense, ["LD"], [], ["RD"], new Set(["D"]));
  return build(
    [
      { kind: "line", players: line },
      { kind: "line", players: pairing },
      { kind: "line", players: goalies },
    ],
    unplaced
  );
}

// --- Placement ---

/**
 * Sorts people onto a left side, a middle and a right side by position:
 * `left` and `right` name the positions that belong to a side (in preference
 * order), `flank` the generic ones that could go either way — those go to
 * whichever side is shorter, ties to the left unless told otherwise — and
 * everything else is the middle, in arrival order.
 */
function split(
  people: GameRosterPerson[],
  left: string[],
  right: string[],
  flank: Set<string>,
  tiesLeft: boolean
): { left: GameRosterPerson[]; right: GameRosterPerson[]; middle: GameRosterPerson[] } {
  const rank = (order: string[], person: GameRosterPerson) => {
    const index = order.indexOf(code(person));
    return index === -1 ? 0 : index;
  };
  const lefts = people
    .filter((p) => left.includes(code(p)))
    .sort((a, b) => rank(left, a) - rank(left, b));
  const rights = people
    .filter((p) => right.includes(code(p)))
    .sort((a, b) => rank(right, a) - rank(right, b));
  const middle: GameRosterPerson[] = [];
  for (const person of people) {
    const c = code(person);
    if (left.includes(c) || right.includes(c)) continue;
    if (flank.has(c)) {
      const goesLeft =
        lefts.length < rights.length || (lefts.length === rights.length && tiesLeft);
      // Outward: a second left wideout stands outside the first.
      if (goesLeft) lefts.unshift(person);
      else rights.push(person);
    } else {
      middle.push(person);
    }
  }
  return { left: lefts, right: rights, middle };
}

function arrange(
  people: GameRosterPerson[],
  left: string[],
  middle: string[],
  right: string[],
  flank: Set<string>
): GameRosterPerson[] {
  const parts = split(people, left, right, flank, true);
  const ordered = parts.middle
    .map((person, offset) => ({ person, offset }))
    .sort((a, b) => {
      const l = indexOr(middle, code(a.person), middle.length);
      const r = indexOr(middle, code(b.person), middle.length);
      return l !== r ? l - r : a.offset - b.offset;
    })
    .map((entry) => entry.person);
  return [...parts.left, ...ordered, ...parts.right];
}

function indexOr(order: string[], value: string, fallback: number): number {
  const index = order.indexOf(value);
  return index === -1 ? fallback : index;
}
