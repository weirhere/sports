// Core domain types for College Football Hub
// All components import from here — never from raw API types.

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
}

export interface Conference {
  id: string;
  name: string;
  shortName: string;
  division: Division;
  logoUrl?: string;
}

export interface Player {
  id: string;
  espnId: number;
  displayName: string;
  firstName: string;
  lastName: string;
  jersey?: string;
  position: string; // "QB", "WR", etc.
  teamId: string; // app team ID
  teamName: string; // school name
  headshotUrl?: string;
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
}

export interface RankedTeam {
  rank: number;
  team: Team;
  record: string;
  previousRank?: number;
  votes: number;
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

export interface GameDetail {
  game: Game;
  boxScore: BoxScore;
  plays: Play[];
  homeStats: TeamStats;
  awayStats: TeamStats;
}

export interface WeekInfo {
  number: number;
  label: string; // "Week 1", "Bowl Games", etc.
  startDate: string;
  endDate: string;
  isCurrent: boolean;
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
