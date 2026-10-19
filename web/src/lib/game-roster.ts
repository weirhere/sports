// Who is in a game — the Roster tab's model, the web twin of iOS
// `GameRoster` (StatSideShared/Models/GameRoster.swift, E29, 2026-10-18).
//
// One shape across three states of a game. Before kickoff it answers "who is
// planning to play": the projected starters over the rest of the roster.
// Live it answers "who is playing": the starters (or, in hockey, the skaters
// on the ice right now) over the bench. After the final it answers "who
// played": the starters over everyone else who got on the field. The lists
// are the same three in every state — `starters`, `others`, `inactive` — and
// the tab names them for the state it is in.
//
// Assembled, not fetched: `makeGameRoster` joins up to four sources per side
// (the team's own roster, the game-day roster, a depth chart and the
// summary's box score and injuries), each of which may be missing, and the
// result is whatever the sources support. A side with nothing behind it is
// empty, which is what hides the tab's cards rather than failing the page.
//
// Pure, so every rule here is testable against a capture; the fetches live
// in `espn/provider.ts` and the route behind `/api/game/{id}/roster`.

import type { League } from "@/lib/leagues";
import type {
  BoxScorePlayer,
  BoxScoreTeam,
  DepthSlot,
  GameInjury,
  GameStatus,
  LineupEntry,
  RosterCoach,
  Team,
  TeamRoster,
} from "@/lib/types";
import { gameState } from "@/lib/game-state";
import { isFootball, unitFor } from "@/lib/formation";

export type GameRosterPhase = "upcoming" | "live" | "played";

/** Football's platoons. A starter belongs to one; the formation draws one
 *  at a time, the other team's opposite unit facing it. */
export type GameRosterUnit = "offense" | "defense" | "specialTeams";

export const UNIT_ORDER: readonly GameRosterUnit[] = ["offense", "defense", "specialTeams"];

/** The card's or caption's word for a unit. */
export function unitTitle(unit: GameRosterUnit): string {
  switch (unit) {
    case "offense":
      return "Offense";
    case "defense":
      return "Defense";
    case "specialTeams":
      return "Special teams";
  }
}

/**
 * Where a side's `starters` came from, which is what the card calls them: a
 * depth chart or a pre-game declaration is a projection, a game-day roster or
 * box score is the lineup, hockey's `onIce` is the five or six skaters out
 * there now.
 */
export type LineupKind = "none" | "declared" | "projected" | "onIce";

export interface GameRosterPerson {
  /** ESPN's athlete id, the key every source shares. */
  id: string;
  /** The full name where any source had it; ESPN's short form ("E. Greene
   *  III") where only the game-day roster did. */
  name: string;
  /** What fits under a formation disc: the game-day roster's own short
   *  form, which already initials a team's two Joneses. */
  shortName: string;
  jersey?: string;
  position?: string;
  positionName?: string;
  headshotUrl?: string;
  unit?: GameRosterUnit;
  /** Why a player sits where he does: "Coach's decision", a scratch, or
   *  nothing. */
  note?: string;
}

export interface GameRosterSide {
  team: Team;
  coach?: RosterCoach;
  starters: GameRosterPerson[];
  lineupKind: LineupKind;
  /** The rest: the roster before kickoff, the bench during, and everyone
   *  else who played after. */
  others: GameRosterPerson[];
  /** Declared inactive, did not play, or scratched. */
  inactive: GameRosterPerson[];
  injuries: GameInjury[];
}

export interface GameRoster {
  phase: GameRosterPhase;
  away: GameRosterSide;
  home: GameRosterSide;
}

export function sideIsEmpty(side: GameRosterSide): boolean {
  return (
    side.coach === undefined &&
    side.starters.length === 0 &&
    side.others.length === 0 &&
    side.inactive.length === 0 &&
    side.injuries.length === 0
  );
}

export function rosterIsEmpty(roster: GameRoster): boolean {
  return sideIsEmpty(roster.away) && sideIsEmpty(roster.home);
}

/**
 * Two sides' people under one unit's caption — how every football list on
 * the Roster tab that isn't the coaches, the inactives or the injured is
 * grouped (Andy, 2026-10-18): the starters' list cards and the bench alike
 * split into Offense, Defense and Special teams, so a kicker — never one of
 * the 22 "starters" ESPN flags — has a named place instead of a slot
 * somewhere in a jersey-ordered bench. The NBA and NHL have no units, so
 * theirs is one group with no caption.
 */
export interface UnitGroup {
  id: string;
  /** Undefined for the people no unit claims: football's unplaceable
   *  positions, or everyone in a league without platoons. */
  unit?: GameRosterUnit;
  away: GameRosterPerson[];
  home: GameRosterPerson[];
}

/**
 * `away` and `home` split by unit in the field's order — offense, defense,
 * special teams, then the unplaced — each side's run in the order it came,
 * groups neither side fills dropped. Outside football it is the one unitless
 * group, or nothing.
 */
export function unitGroups(
  away: GameRosterPerson[],
  home: GameRosterPerson[],
  league: League
): UnitGroup[] {
  const units: (GameRosterUnit | undefined)[] = isFootball(league)
    ? [...UNIT_ORDER, undefined]
    : [undefined];
  return units
    .map((unit) => ({
      id: unit ?? "other",
      unit,
      away: away.filter((person) => person.unit === unit),
      home: home.filter((person) => person.unit === unit),
    }))
    .filter((group) => group.away.length > 0 || group.home.length > 0);
}

// --- Assembly ---

/** Everything one side's lists can be built from. Every source is optional;
 *  the assembly uses what arrived. */
export interface GameRosterSideInput {
  team: Team;
  roster?: TeamRoster;
  lineup?: LineupEntry[];
  depthChart?: DepthSlot[];
  /** The summary's box score for this side. */
  boxScore?: BoxScoreTeam;
  injuries?: GameInjury[];
  /** Hockey's skaters in play right now. */
  onIce?: string[];
}

export function makeGameRoster(
  phase: GameRosterPhase,
  league: League,
  away: GameRosterSideInput,
  home: GameRosterSideInput
): GameRoster {
  return {
    phase,
    away: makeSide(away, phase, league),
    home: makeSide(home, phase, league),
  };
}

/** Roster groups whose players aren't candidates to play: ESPN's own names
 *  for them, as `transformRoster` renders them. */
const NON_PLAYING_GROUPS = new Set(["Injured reserve", "Suspended", "Practice squad"]);

export function makeSide(
  input: GameRosterSideInput,
  phase: GameRosterPhase,
  league: League
): GameRosterSide {
  const lineup = input.lineup ?? [];
  const depthChart = input.depthChart ?? [];
  const injuries = input.injuries ?? [];

  // 1. A directory of everyone any source named, keyed by athlete id. The
  // team roster is the richest (full name, photo, height); the box score
  // fills in anyone it missed — a practice-squad elevation, or everyone, on
  // a past-season game with no roster to ask.
  const directory = new Map<string, GameRosterPerson>();
  const rosterOrder: string[] = [];
  for (const group of input.roster?.groups ?? []) {
    const plays = !NON_PLAYING_GROUPS.has(group.name);
    for (const player of group.players) {
      directory.set(player.id, {
        id: player.id,
        name: player.name,
        shortName: shortName(player.name),
        jersey: player.jersey,
        position: player.position,
        positionName: player.positionName,
        headshotUrl: player.headshotUrl,
        unit: unitFor(player.position, league),
      });
      if (plays) rosterOrder.push(player.id);
    }
  }
  const boxPlayers: BoxScorePlayer[] = [];
  const seenBox = new Set<string>();
  for (const category of input.boxScore?.categories ?? []) {
    for (const player of category.players) {
      const id = player.athleteId;
      if (!id || seenBox.has(id)) continue;
      seenBox.add(id);
      boxPlayers.push(player);
      if (!directory.has(id)) {
        directory.set(id, {
          id,
          name: player.name,
          shortName: shortName(player.name),
          jersey: player.jersey,
          position: player.position,
          positionName: player.positionName,
          headshotUrl: player.headshotUrl,
          unit: unitFor(player.position, league),
        });
      }
    }
  }

  // The person a game-day entry names. The directory's facts win where it
  // has them — the team roster's "OLB" over the core API's generic "LB" —
  // and the entry's own fill the gaps.
  const person = (entry: LineupEntry): GameRosterPerson => {
    const short = entry.shortName && entry.shortName.length > 0 ? entry.shortName : undefined;
    const known = directory.get(entry.athleteId);
    const result: GameRosterPerson = known
      ? { ...known }
      : {
          id: entry.athleteId,
          name: short ?? (entry.jersey ? `No. ${entry.jersey}` : "Unknown"),
          shortName: short ?? (entry.jersey ? `#${entry.jersey}` : "—"),
        };
    if (short) result.shortName = short;
    if (result.jersey === undefined) result.jersey = entry.jersey;
    if (result.position === undefined && entry.position) {
      result.position = entry.position.abbreviation;
      result.positionName = entry.position.name;
    }
    result.unit = unitFor(result.position, league);
    result.note = entry.note;
    return result;
  };

  const boxPerson = (player: BoxScorePlayer): GameRosterPerson | undefined => {
    const id = player.athleteId;
    if (!id) return undefined;
    const known = directory.get(id);
    if (!known) return undefined;
    const result = { ...known };
    if (player.didNotPlay) result.note = player.didNotPlayReason;
    return result;
  };

  const side: GameRosterSide = {
    team: input.team,
    coach: input.roster?.coach,
    starters: [],
    lineupKind: "none",
    others: [],
    inactive: [],
    injuries,
  };
  const injured = new Set(injuries.map((injury) => injury.id));

  if (lineup.length > 0) {
    // The game-day roster is the record. Which of the non-starters "played"
    // depends on whether the league says who didn't: the NFL, NBA and NHL
    // flag inactives, so everyone else dressed; college football flags
    // nobody, so the stat line is the only evidence a player got on the
    // field.
    const declaresInactives = lineup.some((entry) => entry.didNotPlay || entry.isScratched);
    const starters: GameRosterPerson[] = [];
    const out: GameRosterPerson[] = [];
    const rest: GameRosterPerson[] = [];
    for (const entry of lineup) {
      if (entry.isStarter) starters.push(person(entry));
      else if (entry.didNotPlay || entry.isScratched) out.push(person(entry));
      else if (phase === "upcoming" || declaresInactives || entry.recordedStat) {
        rest.push(person(entry));
      }
    }
    side.starters = starters;
    side.inactive = sortedByJersey(out);
    side.others = sortedByJersey(rest.filter((p) => !injured.has(p.id)));
    side.lineupKind =
      starters.length === 0 ? "none" : phase === "upcoming" ? "projected" : "declared";
  } else if (phase !== "upcoming" && boxPlayers.length > 0) {
    // No game-day roster, but a box score: its own flags are the lineup
    // (basketball), or it is simply the list of who played.
    const starters = compact(boxPlayers.filter((p) => p.isStarter === true).map(boxPerson));
    side.starters = starters;
    side.inactive = sortedByJersey(compact(boxPlayers.filter((p) => p.didNotPlay).map(boxPerson)));
    side.others = sortedByJersey(
      compact(boxPlayers.filter((p) => !p.didNotPlay && p.isStarter !== true).map(boxPerson))
        .filter((p) => !injured.has(p.id))
    );
    side.lineupKind = starters.length === 0 ? "none" : "declared";
  } else {
    // Before kickoff with nothing game-specific yet: the team's roster, with
    // the depth chart's first unit on top where the league has one. The
    // chart's slot is the position shown — "PG" says more about where a
    // player stands than the roster's "G".
    const starters: GameRosterPerson[] = [];
    const placed = new Set<string>();
    for (const slot of depthChart) {
      if (slot.rank !== 1 || placed.has(slot.athleteId)) continue;
      const known = directory.get(slot.athleteId);
      if (!known) continue;
      placed.add(slot.athleteId);
      starters.push({
        ...known,
        position: slot.position,
        positionName: slot.positionName ?? known.positionName,
        unit: unitFor(slot.position, league),
      });
    }
    side.starters = starters;
    side.others = compact(
      rosterOrder
        .filter((id) => !placed.has(id) && !injured.has(id))
        .map((id) => directory.get(id))
    );
    side.lineupKind = starters.length === 0 ? "none" : "projected";
  }

  // Hockey, live: the skaters and goalie on the ice are the lineup for as
  // long as they're out there, whatever the depth chart said.
  if (phase === "live") {
    const onIce = compact((input.onIce ?? []).map((id) => directory.get(id)));
    if (onIce.length > 0) {
      const ids = new Set(onIce.map((p) => p.id));
      side.others = sortedByJersey([...side.starters, ...side.others].filter((p) => !ids.has(p.id)));
      side.starters = onIce;
      side.lineupKind = "onIce";
    }
  }

  // A name in one list is in no other.
  const starterIds = new Set(side.starters.map((p) => p.id));
  side.others = side.others.filter((p) => !starterIds.has(p.id));
  const inactiveIds = new Set(side.inactive.map((p) => p.id));
  side.others = side.others.filter((p) => !inactiveIds.has(p.id));
  return side;
}

function compact<T>(values: (T | undefined)[]): T[] {
  return values.filter((value): value is T => value !== undefined);
}

/** "Mahomes" out of "Patrick Mahomes"; the last word that isn't a suffix,
 *  so a formation disc never reads "III". */
export function shortName(name: string): string {
  const suffixes = new Set(["Jr.", "Sr.", "II", "III", "IV", "V"]);
  const words = name.split(" ").filter((word) => word.length > 0 && !suffixes.has(word));
  return words[words.length - 1] ?? name;
}

/** Jersey order, numberless last, otherwise stable — the team roster's rule
 *  for the same reason: the number is how a bench is scanned. */
export function sortedByJersey(people: GameRosterPerson[]): GameRosterPerson[] {
  const number = (person: GameRosterPerson) => {
    if (person.jersey === undefined) return undefined;
    const parsed = Number(person.jersey);
    return Number.isInteger(parsed) ? parsed : undefined;
  };
  return [...people].sort((a, b) => {
    const left = number(a);
    const right = number(b);
    if (left === right) return 0;
    if (left === undefined) return 1;
    if (right === undefined) return -1;
    return left - right;
  });
}

// --- Naming ---

/** What the section calls the eleven, five or six it shows. */
export function startersTitle(roster: GameRoster): string {
  const kinds = [roster.away.lineupKind, roster.home.lineupKind];
  if (kinds.includes("onIce")) return "On the ice";
  if (kinds.includes("declared")) return "Starters";
  return "Projected starters";
}

/** One side declared, the other only projected: say so once. */
export function startersSubtitle(roster: GameRoster): string | undefined {
  const kinds = [roster.away.lineupKind, roster.home.lineupKind];
  if (!kinds.includes("declared") || !kinds.includes("projected")) return undefined;
  const projected = roster.away.lineupKind === "projected" ? roster.away.team : roster.home.team;
  return `${teamShortName(projected)} projected`;
}

/** What the non-starters are, in this state of the game. A pre-game side
 *  with no projected starters at all is simply its roster. */
export function othersTitle(phase: GameRosterPhase): string {
  switch (phase) {
    case "upcoming":
      return "Roster";
    case "live":
      return "Bench";
    case "played":
      return "Also played";
  }
}

/** Each league's own word for the players who dressed in name only. */
export function inactiveTitle(league: League): string {
  switch (league) {
    case "cfb":
    case "nfl":
      return "Inactive";
    case "nba":
      return "Did not play";
    case "nhl":
      return "Scratched";
  }
}

/** What the sport calls the place its starters are drawn on. */
export function surfaceName(league: League): string {
  switch (league) {
    case "cfb":
    case "nfl":
      return "Field";
    case "nba":
      return "Court";
    case "nhl":
      return "Rink";
  }
}

export function teamShortName(team: Team): string {
  return team.abbreviation || team.school;
}

/** The Roster tab's phase: which of "planning to play", "playing" and
 *  "played" the lists answer (iOS `GameHeaderState.rosterPhase`). */
export function rosterPhase(status: GameStatus): GameRosterPhase {
  switch (gameState(status)) {
    case "pre":
      return "upcoming";
    case "live":
      return "live";
    case "final":
    case "other":
      return "played";
  }
}

/**
 * The game page's first tab, named by state: "Preview" before kickoff and
 * "Facts" from the first snap on (Andy, 2026-10-18 — FotMob's naming, and
 * the same cards either way). Postponed and cancelled games read "Facts"
 * too: there is no game ahead to preview.
 */
export function factsTabTitle(status: GameStatus): string {
  return gameState(status) === "pre" ? "Preview" : "Facts";
}
