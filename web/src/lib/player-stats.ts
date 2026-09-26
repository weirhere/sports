// A player's numbers — the web twin of iOS `PlayerStats` and `PlayerGameLog`
// (StatSideShared/Models/PlayerStats.swift).
//
// **ESPN's categories and column labels are carried through, never named
// here** — the box score's lesson (2026-09-05) without amendment. A
// quarterback leads with `passing`, a receiver with `receiving`, the NBA
// ships `averages` and `totals`, and hockey splits `goaltender` from the
// skaters. ESPN orders a player's categories by what they actually do, so
// the first one is the player's own table — which is what the This season
// card reads.
//
// Every season the player has a line for is a row, with the club they
// played it for. That *is* the Career tab: no aggregation, and ESPN's own
// `totals` as the career line rather than a sum the app computed
// (2026-09-24).

export interface PlayerSeasonLine {
  /** ESPN's season year — the *ending* year for basketball and hockey. */
  year: number;
  /** "2026", "2025-26" — whatever ESPN calls it. */
  label: string;
  teamId?: string;
  /** The club's name, from the payload's own `teams` map. */
  teamName?: string;
  /** The club's abbreviation, from the same map — the Career row's caption. */
  teamAbbreviation?: string;
  position?: string;
  values: string[];
}

export interface PlayerStatsCategory {
  /** ESPN's machine name: "passing", "averages", "goaltender". */
  id: string;
  /** ESPN's heading: "Passing", "Regular Season Averages". */
  title: string;
  /** Column headers — "GP", "YDS", "TD". */
  labels: string[];
  /**
   * Stable column keys — "gamesPlayed", "passingYards". What the headline
   * registry matches on, so a relabelled column can't move which number
   * the card shows.
   */
  names: string[];
  /**
   * ESPN's full column names — "Passing Yards". Not its `descriptions[]`,
   * which are glossary sentences and read like a textbook in a list.
   */
  displayNames: string[];
  /** Oldest first, as ESPN sends them. */
  seasons: PlayerSeasonLine[];
  /** ESPN's career line, positionally paired with `labels`. Empty when it
   *  doesn't match the header. */
  career: string[];
}

export interface PlayerStats {
  categories: PlayerStatsCategory[];
}

/** One of the This season card's numbers. */
export interface PlayerHeadline {
  label: string;
  spokenLabel: string;
  value: string;
}

/** A player traded mid-season has two lines for one year. */
export function seasonLineId(line: PlayerSeasonLine): string {
  return `${line.year}-${line.teamId ?? ""}`;
}

/** The value in the column ESPN names `name`, for one line. */
export function categoryValue(
  category: PlayerStatsCategory,
  name: string,
  values: string[]
): string | undefined {
  const index = category.names.indexOf(name);
  if (index === -1 || index >= values.length) return undefined;
  const value = values[index];
  return value === "" || value === "-" ? undefined : value;
}

/** The lines for one ESPN season year — usually one, two for a player
 *  traded mid-season. */
export function linesForYear(
  category: PlayerStatsCategory,
  year: number
): PlayerSeasonLine[] {
  return category.seasons.filter((line) => line.year === year);
}

const SKATER_CATEGORIES = new Set([
  "center",
  "leftWing",
  "rightWing",
  "defense",
  "forward",
  "skater",
]);

/**
 * Which columns lead, keyed by ESPN's category name rather than by league —
 * a receiver in either football league is the same question. A category
 * this doesn't know shows its first three columns after games played, which
 * is ESPN's own order of importance.
 *
 * A straight copy of iOS `PlayerStats.headlineNames(for:)`; the two must
 * agree or one player reads differently on the two platforms.
 */
export function headlineNames(category: PlayerStatsCategory): string[] {
  switch (category.id) {
    case "passing":
      return ["passingYards", "passingTouchdowns", "interceptions"];
    case "rushing":
      return ["rushingYards", "rushingTouchdowns", "yardsPerRushAttempt"];
    case "receiving":
      return ["receptions", "receivingYards", "receivingTouchdowns"];
    case "averages":
      return ["avgPoints", "avgRebounds", "avgAssists"];
    case "goaltender":
      return ["wins", "avgGoalsAgainst", "savePct"];
    default:
      if (SKATER_CATEGORIES.has(category.id)) {
        return ["goals", "assists", "points"];
      }
      return category.names
        .filter((name) => name !== "gamesPlayed" && name !== "games")
        .slice(0, 3);
  }
}

/**
 * The This season card's contents: games played, then the two or three
 * numbers the player's own category is about — or nothing, which hides the
 * card. A player with no line this season has no current season, and a row
 * of zeroes would say otherwise.
 *
 * A traded player's lines for the year are not summed: the last line ESPN
 * lists stands, because the app does not publish a figure it computed.
 */
export function seasonHeadlines(
  stats: PlayerStats,
  espnYear: number
): PlayerHeadline[] {
  const category = stats.categories[0];
  if (!category) return [];
  const line = linesForYear(category, espnYear).at(-1);
  if (!line) return [];

  const wanted = ["gamesPlayed", "games", ...headlineNames(category)];
  const seen = new Set<string>();
  const headlines: PlayerHeadline[] = [];
  for (const name of wanted) {
    const index = category.names.indexOf(name);
    if (index === -1) continue;
    const value = categoryValue(category, name, line.values);
    const label = category.labels[index];
    if (value === undefined || label === undefined || seen.has(label)) continue;
    seen.add(label);
    headlines.push({
      label,
      spokenLabel: category.displayNames[index] ?? label,
      value,
    });
  }
  return headlines;
}

/** The season label the This season card names, or undefined. */
export function seasonLabelFor(
  stats: PlayerStats,
  espnYear: number
): string | undefined {
  const category = stats.categories[0];
  return category ? linesForYear(category, espnYear).at(-1)?.label : undefined;
}

// --- Game log -----------------------------------------------------------

export interface PlayerGameLogEntry {
  eventId: string;
  /** ISO string, as ESPN sent it — survives the server/client boundary. */
  date?: string;
  /** Football only; ESPN sends none for basketball or hockey. */
  week?: number;
  /** True for "@", false for "vs". */
  isAway: boolean;
  opponentId?: string;
  opponentAbbreviation?: string;
  opponentName?: string;
  opponentLogoUrl?: string;
  /** The player's own side that night — a traded player's log crosses
   *  clubs, so this is per game, not per page. */
  teamId?: string;
  /** "W", "L", "T" — or undefined for a game not yet decided. */
  result?: string;
  teamScore?: string;
  opponentScore?: string;
  /** "West Semifinals - Game 4". */
  note?: string;
  /** Positionally paired with the log's `labels`. */
  values: string[];
}

/** "2025-26 Regular Season", "2025-26 Postseason". */
export interface PlayerGameLogSection {
  title: string;
  /** Newest first, the way ESPN lists them. */
  entries: PlayerGameLogEntry[];
}

export interface PlayerGameLog {
  labels: string[];
  names: string[];
  /** Newest season type first. */
  sections: PlayerGameLogSection[];
  /** The seasons ESPN will answer for, newest first, in ESPN's numbering. */
  availableSeasons: number[];
  /** The season this log is for, in ESPN's numbering. */
  season?: number;
}

export function gameLogIsEmpty(log: PlayerGameLog): boolean {
  return log.sections.every((section) => section.entries.length === 0);
}

/**
 * The short line a game row prints — the same columns the This season card
 * leads with, looked up by name in this log's own header. iOS
 * `PlayerGameLog.headline(for:category:)`.
 */
export function gameLogHeadline(
  log: PlayerGameLog,
  entry: PlayerGameLogEntry,
  category: string | undefined
): string {
  let picks: string[];
  switch (category) {
    case "passing":
      picks = ["passingYards", "passingTouchdowns", "interceptions"];
      break;
    case "rushing":
      picks = ["rushingYards", "rushingTouchdowns"];
      break;
    case "receiving":
      picks = ["receptions", "receivingYards", "receivingTouchdowns"];
      break;
    case "averages":
    case "totals":
      picks = ["points", "totalRebounds", "assists"];
      break;
    case "goaltender":
      picks = ["saves", "savePct", "goalsAgainst"];
      break;
    default:
      picks =
        category !== undefined && SKATER_CATEGORIES.has(category)
          ? ["goals", "assists", "points"]
          : [];
  }

  const parts: string[] = [];
  for (const name of picks) {
    const index = log.names.indexOf(name);
    if (index === -1 || index >= entry.values.length || index >= log.labels.length) {
      continue;
    }
    parts.push(`${entry.values[index]} ${log.labels[index]}`);
  }
  if (parts.length === 0) {
    // Nothing named — the first three columns, ESPN's own order of
    // importance for this log.
    for (let index = 0; index < Math.min(3, log.labels.length, entry.values.length); index += 1) {
      parts.push(`${entry.values[index]} ${log.labels[index]}`);
    }
  }
  return parts.join(" · ");
}

/** "W 33-30", the player's side first. */
export function gameLogResult(entry: PlayerGameLogEntry): string | undefined {
  if (!entry.result) return undefined;
  if (entry.teamScore === undefined || entry.opponentScore === undefined) {
    return entry.result;
  }
  return `${entry.result} ${entry.teamScore}-${entry.opponentScore}`;
}
