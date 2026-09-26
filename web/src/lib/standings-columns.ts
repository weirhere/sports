// What a standings table shows, per league — a port of iOS
// `StandingsColumn` (StatSideShared/Models/StandingsColumns.swift).
//
// Per league because the leagues genuinely disagree about what a standing
// *is*. Football ranks on records and shows the conference one beside the
// overall. The NBA ranks on win percentage and answers "how far back are
// we" with games behind. The NHL ranks on points — and ships **no
// conference record at all** (`vsconf` is simply absent from its payload,
// verified live 2026-09-09), so a CONF column there would be a permanent
// dash under a caption promising a number.

import type { League } from "./leagues";
import type { ConferenceStanding } from "./types";

export type StandingsField =
  | "inGroupRecord"
  | "overallRecord"
  | "winLossOTL"
  | "gamesPlayed"
  | "points"
  | "winPercent"
  | "gamesBehind"
  | "wins"
  | "losses"
  | "ties"
  | "homeRecord"
  | "awayRecord"
  | "divisionRecord"
  | "pointsFor"
  | "pointsAgainst"
  | "pointDifferential"
  | "streak";

/**
 * Whether the value is a record ("2-0") rather than a number. Only these
 * get the dash-to-"and" treatment when spoken — a differential of "-12"
 * read that way says "and 12".
 */
const RECORD_FIELDS: ReadonlySet<StandingsField> = new Set([
  "inGroupRecord",
  "overallRecord",
  "winLossOTL",
  "homeRecord",
  "awayRecord",
  "divisionRecord",
]);

export interface StandingsColumn {
  field: StandingsField;
  /** The table's own caption — "CONF", "PTS", "GB". */
  caption: string;
  /** What a screen reader calls it inside the row's sentence. */
  spoken: string;
  /** Column width in px, so captions line up with the numbers beneath. */
  width: number;
}

const COLUMNS: Record<League, StandingsColumn[]> = {
  cfb: [
    { field: "inGroupRecord", caption: "CONF", spoken: "in conference", width: 44 },
    { field: "overallRecord", caption: "OVR", spoken: "overall", width: 44 },
  ],
  // The NFL's own table, in ESPN's order (Andy, 2026-09-13). W-L-T
  // replaces the OVR summary rather than sitting beside it: three columns
  // and one string are the same three numbers, and the league that still
  // plays ties is the one that needs them apart. Wider than a phone by
  // design — see `standingsScrollsHorizontally`.
  nfl: [
    { field: "wins", caption: "W", spoken: "wins", width: 22 },
    { field: "losses", caption: "L", spoken: "losses", width: 22 },
    { field: "ties", caption: "T", spoken: "ties", width: 22 },
    { field: "winPercent", caption: "PCT", spoken: "win percentage", width: 42 },
    { field: "homeRecord", caption: "HOME", spoken: "at home", width: 42 },
    { field: "awayRecord", caption: "AWAY", spoken: "away", width: 42 },
    { field: "divisionRecord", caption: "DIV", spoken: "in division", width: 42 },
    { field: "inGroupRecord", caption: "CONF", spoken: "in conference", width: 42 },
    { field: "pointsFor", caption: "PF", spoken: "points for", width: 30 },
    { field: "pointsAgainst", caption: "PA", spoken: "points against", width: 30 },
    { field: "pointDifferential", caption: "DIFF", spoken: "point differential", width: 38 },
    { field: "streak", caption: "STRK", spoken: "streak", width: 34 },
  ],
  nba: [
    { field: "overallRecord", caption: "W-L", spoken: "overall", width: 44 },
    { field: "winPercent", caption: "PCT", spoken: "win percentage", width: 38 },
    { field: "gamesBehind", caption: "GB", spoken: "games back", width: 32 },
  ],
  // Points is the ranking; the record has three numbers because a game
  // lost in overtime is still worth a point.
  nhl: [
    { field: "gamesPlayed", caption: "GP", spoken: "games played", width: 26 },
    { field: "winLossOTL", caption: "W-L-OTL", spoken: "record", width: 76 },
    { field: "points", caption: "PTS", spoken: "points", width: 30 },
  ],
};

export function standingsColumns(league: League): StandingsColumn[] {
  return COLUMNS[league];
}

/**
 * Whether this league's table is wider than the column it sits in, so the
 * identity column pins and the numbers scroll under it (ESPN's and
 * FotMob's pattern). True for exactly the league whose set can't fit: a
 * set that fits must never become a scroller, because a scroller says
 * "there is more here" and there wouldn't be.
 */
export function standingsScrollsHorizontally(league: League): boolean {
  return league === "nfl";
}

/**
 * Whether a game's `/summary` carries the matchup card's tables, so the page
 * can skip fetching the league's (iOS, 2026-09-21). Decided by what the
 * payload contains rather than what it's called: college football's ships
 * **both competing conferences in full**, with `total` and `vsconf` — the
 * card's whole column set. The NBA's and NHL's ship the **division**, short
 * a column at that, and no NFL summary has ever been captured, so those
 * three keep the fetch rather than decode a guessed shape.
 */
export function summaryCarriesMatchupStandings(league: League): boolean {
  return league === "cfb";
}

/**
 * What one column shows for this row, already formatted — undefined where
 * the payload didn't carry the stat, which drops the *number* rather than
 * the row.
 */
export function standingValue(
  entry: ConferenceStanding,
  column: StandingsColumn
): string | undefined {
  switch (column.field) {
    case "inGroupRecord":
      return entry.conferenceRecord;
    // The NHL's `total` summary already *is* the three-part record.
    case "overallRecord":
    case "winLossOTL":
      return entry.overallRecord;
    case "gamesPlayed":
      return entry.gamesPlayed !== undefined ? String(entry.gamesPlayed) : undefined;
    case "points":
      return entry.points !== undefined ? String(entry.points) : undefined;
    case "winPercent":
      // ESPN already writes it the way a table shows it: ".732", zero
      // stripped, which is what every basketball table does.
      return (
        entry.winPercentText ??
        (entry.winPercent !== undefined
          ? entry.winPercent.toFixed(3).replace(/^0/, "")
          : undefined)
      );
    case "gamesBehind":
      return entry.gamesBehind;
    case "wins":
      return entry.wins !== undefined ? String(entry.wins) : undefined;
    case "losses":
      return entry.losses !== undefined ? String(entry.losses) : undefined;
    case "ties":
      return entry.ties !== undefined ? String(entry.ties) : undefined;
    case "homeRecord":
      return entry.homeRecord;
    case "awayRecord":
      return entry.awayRecord;
    case "divisionRecord":
      return entry.divisionRecord;
    case "pointsFor":
      return entry.pointsFor !== undefined ? String(entry.pointsFor) : undefined;
    case "pointsAgainst":
      return entry.pointsAgainst !== undefined
        ? String(entry.pointsAgainst)
        : undefined;
    case "pointDifferential":
      return entry.pointDifferential;
    case "streak":
      return entry.streak;
  }
}

/** Whether this team has played anything yet. A 0-0 row is last season's
 * carried-over order, not information. */
export function hasPlayed(entry: ConferenceStanding): boolean {
  if (entry.gamesPlayed !== undefined) return entry.gamesPlayed > 0;
  const record = entry.overallRecord;
  if (record === undefined) return entry.overallWins + entry.overallLosses > 0;
  return !/^0-0(-0)?$/.test(record.trim());
}

/** The row's whole sentence, for a screen reader — the table's captions
 * are decoration, so the row has to speak them itself. */
export function standingSentence(
  entry: ConferenceStanding,
  league: League,
  place: number
): string {
  const parts = [`${place}. ${entry.team.school}`];
  for (const column of standingsColumns(league)) {
    const value = standingValue(entry, column);
    // "-" is ESPN's own "no games back", which the leader always has.
    if (value === undefined || value === "-") continue;
    parts.push(spokenValue(value, column));
  }
  return parts.join(", ");
}

/** One column, as a phrase. Hockey's three-part record names its parts
 * rather than reading as "50 and 23 and 9 and overtime losses". */
function spokenValue(value: string, column: StandingsColumn): string {
  if (column.field === "winLossOTL") {
    const [wins, losses, otLosses] = value.split("-");
    const parts = [`${wins} wins`, `${losses} losses`];
    if (otLosses !== undefined) parts.push(`${otLosses} overtime losses`);
    return parts.join(", ");
  }
  if (column.field === "streak") {
    // "W3" is a table's shorthand, not a sentence: the letter and the
    // number run together in every voice that reads it.
    const verb = value.startsWith("W") ? "won" : value.startsWith("L") ? "lost" : "";
    if (verb) return `${verb} ${value.slice(1)} ${column.spoken}`;
    return `${value} ${column.spoken}`;
  }
  // Records only. A differential's "-12" means minus, and saying "and 12"
  // would invert it.
  const spelled = RECORD_FIELDS.has(column.field)
    ? value.replaceAll("-", " and ")
    : value;
  return `${spelled} ${column.spoken}`;
}
