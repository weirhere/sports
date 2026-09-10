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
  | "gamesBehind";

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
  nfl: [
    { field: "inGroupRecord", caption: "CONF", spoken: "in conference", width: 44 },
    { field: "overallRecord", caption: "OVR", spoken: "overall", width: 44 },
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
  return `${value.replaceAll("-", " and ")} ${column.spoken}`;
}
