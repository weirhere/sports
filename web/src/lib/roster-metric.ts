// The one right-aligned column a roster row carries — FotMob's "Age" slot,
// per league. A port of iOS `RosterMetric`
// (StatSideShared/Models/TeamRoster.swift).
//
// Per league for the same reason `standingsColumns` is: the leagues ship
// different facts. College football publishes **no age at all** (0 of 100
// players, probed live) and a class year instead, so an AGE caption there
// would promise a number that never arrives.

import type { League } from "./leagues";
import type { RosterPlayer } from "./types";

export type RosterMetricField = "age" | "classYear";

export interface RosterMetric {
  field: RosterMetricField;
  /** The table's own caption — "AGE", "CLASS". */
  caption: string;
  /** Column width in px, so the caption lines up with the values beneath. */
  width: number;
}

const METRICS: Record<League, RosterMetric> = {
  cfb: { field: "classYear", caption: "CLASS", width: 44 },
  nfl: { field: "age", caption: "AGE", width: 44 },
  nba: { field: "age", caption: "AGE", width: 44 },
  nhl: { field: "age", caption: "AGE", width: 44 },
};

export function rosterMetric(league: League): RosterMetric {
  return METRICS[league];
}

/** The value under this league's metric column, or undefined where the
 *  player is missing it — which drops the number, never the row. */
export function rosterMetricValue(
  player: RosterPlayer,
  metric: RosterMetric
): string | undefined {
  switch (metric.field) {
    case "age":
      return player.age !== undefined ? String(player.age) : undefined;
    case "classYear":
      return player.classAbbreviation;
  }
}

/** ESPN abbreviates the class; a screen reader shouldn't have to spell it. */
const CLASS_NAMES: Record<string, string> = {
  FR: "freshman",
  SO: "sophomore",
  JR: "junior",
  SR: "senior",
};

/** What the metric is called inside the row's spoken sentence. */
export function spokenMetric(value: string, metric: RosterMetric): string {
  return metric.field === "age"
    ? `age ${value}`
    : (CLASS_NAMES[value] ?? value);
}

/**
 * The row's whole sentence, for a screen reader — the table's captions are
 * decoration, so the row has to speak itself.
 *
 * "12, Patrick Mahomes, Quarterback, 6' 2", 225 lbs, age 30". The position is
 * spoken in full: "QB" is read as letters, and a roster is exactly the place
 * a listener is learning who these people are.
 */
export function rosterSentence(
  player: RosterPlayer,
  metric: RosterMetric
): string {
  const parts: string[] = [];
  if (player.jersey) parts.push(`Number ${player.jersey}`);
  parts.push(player.name);
  const position = player.positionName ?? player.position;
  if (position) parts.push(position);
  if (player.height) parts.push(player.height);
  if (player.weight) parts.push(player.weight);
  const value = rosterMetricValue(player, metric);
  if (value) parts.push(spokenMetric(value, metric));
  if (player.injuryStatus) parts.push(player.injuryStatus);
  return parts.join(", ");
}
