// Core domain types for College Football Hub
// All components import from here — never from raw API types.

import type { LivePhase } from "./format";
import type { WeekSlot } from "./season";

export type GameStatus =
  | "scheduled"
  | "in_progress"
  | "halftime"
  | "end_period"
  | "complete"
  | "postponed"
  | "cancelled"
  | "delayed";

export type Division = "FBS" | "FCS";

export interface Team {
  id: string;
  espnId: number;
  name: string; // e.g., "Crimson Tide"
  school: string; // e.g., "Alabama"
  abbreviation: string; // e.g., "ALA"
  conferenceId: string;
  conferenceName: string;
  division: Division;
  color?: string; // Primary brand color hex
  altColor?: string;
  logoUrl: string;
}

export interface GameTeam {
  team: Team;
  score: number | null;
  ranking?: number; // AP ranking if ranked
  record?: string; // e.g., "8-2"
  isWinner?: boolean;
  linescores?: number[]; // Quarter-by-quarter scores
}

export interface Venue {
  name: string;
  city: string;
  state: string;
}

export interface Game {
  id: string;
  status: GameStatus;
  scheduledAt: string; // ISO 8601
  venue: Venue;
  homeTeam: GameTeam;
  awayTeam: GameTeam;
  broadcast?: string; // TV network
  clock?: string; // Game clock e.g., "3:42"
  quarter?: number; // Current quarter (1-4, 5=OT)
  possession?: "home" | "away";
  week: number;
  seasonYear: number;
  conferenceGame: boolean;
  /**
   * ESPN publishes a placeholder kickoff (midnight ET, `timeValid: false`)
   * until a game's time is announced. True means `scheduledAt`'s day is
   * real but its clock time is noise — render "TBD", never "12:00 AM".
   */
  timeTBD?: boolean;
  /**
   * ESPN's season type (2 regular, 3 postseason) when the payload says.
   * Week numbers restart in the postseason, so grouping a season's slate
   * by week needs this to keep a title game out of "Week 1".
   */
  seasonType?: number;
  /**
   * Where a live game's clock cycle stands. ESPN sends halftime and
   * end-of-quarter as `state: "in"` with the clock parked at 0:00 — set at
   * the transform boundary so renderers never re-derive it.
   */
  livePhase?: LivePhase;
  /** ESPN's status detail string — the degrade path for status lines. */
  statusDetail?: string;
}

export interface Conference {
  id: string;
  name: string;
  shortName: string;
  division: Division;
  logoUrl?: string;
}

export interface ConferenceStanding {
  team: Team;
  conferenceWins: number;
  conferenceLosses: number;
  overallWins: number;
  overallLosses: number;
  conferenceRank: number;
  streakType?: "W" | "L";
  streakLength?: number;
  /** ESPN's record summary strings ("7-1") — display verbatim. */
  conferenceRecord?: string;
  overallRecord?: string;
  streak?: string;
  /**
   * ESPN's `playoffSeed` — the tiebreaker-aware standings position.
   * 1-based when ESPN knows it; absent (or ESPN's 0) when it doesn't.
   */
  playoffSeed?: number;
}

/**
 * A conference's standings in ESPN's order — which encodes tiebreakers and
 * is not derivable from the records. Empty `entries` are kept: offseason
 * responses can have zero entries and the page needs to say "Standings
 * TBA", not error.
 */
export interface ConferenceStandingsGroup {
  id: string;
  name: string;
  entries: ConferenceStanding[];
}

/** One FBS conference with its member teams (alphabetical), for browsing. */
export interface ConferenceTeams {
  id?: string;
  name: string;
  teams: Team[];
}

export interface RankedTeam {
  rank: number;
  team: Team;
  record: string;
  previousRank?: number;
  votes: number;
  firstPlaceVotes?: number;
}

/** One poll as ESPN publishes it, ranks included. */
export interface Poll {
  id: string;
  name: string;
  shortName?: string;
  type?: string;
  headline?: string;
  ranks: RankedTeam[];
}

export type PollType = "cfp" | "ap" | "coaches";

export interface RankingsData {
  type: PollType;
  label: string;
  teams: RankedTeam[];
}

export interface ScoringDrive {
  team: "home" | "away";
  quarter: number;
  description: string;
  plays: number;
  yards: number;
  timeOfPossession: string;
  result: string; // "Touchdown", "Field Goal", etc.
}

export interface BoxScore {
  gameId: string;
  homeTeam: GameTeam;
  awayTeam: GameTeam;
  scoringDrives: ScoringDrive[];
}

export interface Play {
  id: string;
  quarter: number;
  clock: string;
  down?: number;
  distance?: number;
  yardLine?: number;
  description: string;
  team: "home" | "away";
  type: string; // "rush", "pass", "penalty", "kickoff", etc.
  yards?: number;
  scoringPlay?: boolean;
}

export interface TeamStats {
  totalYards: number;
  passingYards: number;
  rushingYards: number;
  turnovers: number;
  penalties: number;
  penaltyYards: number;
  firstDowns: number;
  thirdDownEfficiency: string; // "5-12"
  fourthDownEfficiency: string; // "1-2"
  timeOfPossession: string; // "32:15"
  redZoneEfficiency: string; // "2-3"
  sacks: number;
  interceptions: number;
  fumbles: number;
}

/** One side's leader in a stat category. */
export interface GameLeader {
  name: string;
  statLine: string;
  headshotUrl?: string;
}

/** A leader category ("Passing") with both sides filled in where known. */
export interface LeaderCategory {
  id: string;
  label: string;
  away?: GameLeader;
  home?: GameLeader;
}

/** One drive, scoring or not. */
export interface GameDrive {
  id: string;
  teamId?: string;
  result?: string;
  isScore: boolean;
  summary?: string;
  quarter?: number;
}

export interface GameDetail {
  game: Game;
  boxScore: BoxScore;
  plays: Play[];
  homeStats: TeamStats;
  awayStats: TeamStats;
  // Optional summary extras (absent in mock data; populated from ESPN).
  attendance?: number;
  venueCapacity?: number;
  venueSurface?: "grass" | "turf";
  weatherCondition?: string;
  weatherTemperature?: number;
  leaders?: LeaderCategory[];
  drives?: GameDrive[];
}

/** The scoreboard response: the week strip's slots plus the slate. */
export interface Scoreboard {
  seasonYear?: number;
  seasonType?: number;
  currentWeekNumber?: number;
  weeks: WeekSlot[];
  games: Game[];
}

/**
 * One team's season: identity, record, and their games. `record`/`standing`
 * are trusted only when ESPN's summaries describe the requested season;
 * `derivedRecord` (W-L counted from final results) is the honest record for
 * a past season.
 */
export interface TeamScheduleData {
  team?: Team;
  record?: string;
  standing?: string;
  year?: number;
  games: Game[];
  derivedRecord?: string;
}

// Grouped game structures for the scores page
export interface DayGames {
  date: string; // ISO date string (YYYY-MM-DD)
  label: string; // "Saturday, October 12"
  conferenceGroups: ConferenceGameGroup[];
}

export interface ConferenceGameGroup {
  conference: Conference;
  games: Game[];
}
