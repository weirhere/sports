import type { GameDetail, BoxScore, Play, TeamStats, ScoringDrive } from "@/lib/types";
import { MOCK_GAMES } from "./games";

// Detailed data for game g-2 (Alabama 28, Tennessee 24 — completed)
const GAME_G2_DRIVES: ScoringDrive[] = [
  { team: "away", quarter: 1, description: "Joshua Dobbs 12 yd pass to Jalin Hyatt (Chase McGrath kick)", plays: 8, yards: 75, timeOfPossession: "4:12", result: "Touchdown" },
  { team: "home", quarter: 1, description: "Jalen Milroe 3 yd rush (Will Reichard kick)", plays: 6, yards: 65, timeOfPossession: "3:45", result: "Touchdown" },
  { team: "home", quarter: 2, description: "Jalen Milroe 45 yd pass to Jermaine Burton (Will Reichard kick)", plays: 4, yards: 80, timeOfPossession: "1:55", result: "Touchdown" },
  { team: "home", quarter: 2, description: "Jalen Milroe 8 yd rush (Will Reichard kick)", plays: 9, yards: 70, timeOfPossession: "5:22", result: "Touchdown" },
  { team: "away", quarter: 2, description: "Chase McGrath 42 yd field goal", plays: 7, yards: 35, timeOfPossession: "3:30", result: "Field Goal" },
  { team: "away", quarter: 3, description: "Jabari Small 2 yd rush (Chase McGrath kick)", plays: 10, yards: 85, timeOfPossession: "5:45", result: "Touchdown" },
  { team: "away", quarter: 4, description: "Joshua Dobbs 22 yd pass to Bru McCoy (Chase McGrath kick)", plays: 5, yards: 60, timeOfPossession: "2:30", result: "Touchdown" },
  { team: "home", quarter: 4, description: "Jalen Milroe 1 yd rush (Will Reichard kick)", plays: 12, yards: 75, timeOfPossession: "6:15", result: "Touchdown" },
];

const GAME_G2_PLAYS: Play[] = [
  { id: "p-1", quarter: 1, clock: "15:00", description: "Kickoff: Tennessee receives", team: "away", type: "kickoff" },
  { id: "p-2", quarter: 1, clock: "14:48", down: 1, distance: 10, yardLine: 25, description: "Jabari Small rush for 4 yards", team: "away", type: "rush", yards: 4 },
  { id: "p-3", quarter: 1, clock: "14:12", down: 2, distance: 6, yardLine: 29, description: "Joshua Dobbs pass complete to Cedric Tillman for 12 yards", team: "away", type: "pass", yards: 12 },
  { id: "p-4", quarter: 1, clock: "13:35", down: 1, distance: 10, yardLine: 41, description: "Jabari Small rush for 8 yards", team: "away", type: "rush", yards: 8 },
  { id: "p-5", quarter: 1, clock: "12:58", down: 2, distance: 2, yardLine: 49, description: "Joshua Dobbs pass complete to Jalin Hyatt for 15 yards", team: "away", type: "pass", yards: 15 },
  { id: "p-6", quarter: 1, clock: "12:15", down: 1, distance: 10, yardLine: 36, description: "Jaylen Wright rush for 11 yards", team: "away", type: "rush", yards: 11 },
  { id: "p-7", quarter: 1, clock: "11:30", down: 1, distance: 10, yardLine: 25, description: "Joshua Dobbs pass complete to Bru McCoy for 13 yards", team: "away", type: "pass", yards: 13 },
  { id: "p-8", quarter: 1, clock: "10:48", down: 1, distance: 10, yardLine: 12, description: "Joshua Dobbs pass complete to Jalin Hyatt for 12 yards - TOUCHDOWN", team: "away", type: "pass", yards: 12, scoringPlay: true },
  { id: "p-9", quarter: 1, clock: "10:45", description: "Chase McGrath extra point GOOD", team: "away", type: "extra_point" },
  { id: "p-10", quarter: 1, clock: "10:30", description: "Kickoff: Alabama receives", team: "home", type: "kickoff" },
  { id: "p-11", quarter: 1, clock: "10:18", down: 1, distance: 10, yardLine: 35, description: "Jalen Milroe pass complete to Jermaine Burton for 22 yards", team: "home", type: "pass", yards: 22 },
  { id: "p-12", quarter: 1, clock: "9:42", down: 1, distance: 10, yardLine: 43, description: "Jase McClellan rush for 8 yards", team: "home", type: "rush", yards: 8 },
  { id: "p-13", quarter: 1, clock: "9:08", down: 2, distance: 2, yardLine: 35, description: "Jase McClellan rush for 15 yards", team: "home", type: "rush", yards: 15 },
  { id: "p-14", quarter: 1, clock: "8:30", down: 1, distance: 10, yardLine: 20, description: "Jalen Milroe pass complete to Isaiah Bond for 17 yards", team: "home", type: "pass", yards: 17 },
  { id: "p-15", quarter: 1, clock: "7:55", down: 1, distance: 3, yardLine: 3, description: "Jalen Milroe rush for 3 yards - TOUCHDOWN", team: "home", type: "rush", yards: 3, scoringPlay: true },
  { id: "p-16", quarter: 1, clock: "7:52", description: "Will Reichard extra point GOOD", team: "home", type: "extra_point" },
];

const GAME_G2_HOME_STATS: TeamStats = {
  totalYards: 425,
  passingYards: 275,
  rushingYards: 150,
  turnovers: 1,
  penalties: 5,
  penaltyYards: 45,
  firstDowns: 22,
  thirdDownEfficiency: "7-14",
  fourthDownEfficiency: "1-1",
  timeOfPossession: "32:15",
  redZoneEfficiency: "4-4",
  sacks: 2,
  interceptions: 1,
  fumbles: 0,
};

const GAME_G2_AWAY_STATS: TeamStats = {
  totalYards: 380,
  passingYards: 230,
  rushingYards: 150,
  turnovers: 2,
  penalties: 7,
  penaltyYards: 60,
  firstDowns: 20,
  thirdDownEfficiency: "5-12",
  fourthDownEfficiency: "0-1",
  timeOfPossession: "27:45",
  redZoneEfficiency: "3-4",
  sacks: 1,
  interceptions: 0,
  fumbles: 2,
};

export function getGameDetail(gameId: string): GameDetail | undefined {
  const game = MOCK_GAMES.find((g) => g.id === gameId);
  if (!game) return undefined;

  // Return detailed mock data for g-2, generic data for others
  if (gameId === "g-2") {
    return {
      game,
      boxScore: {
        gameId,
        homeTeam: game.homeTeam,
        awayTeam: game.awayTeam,
        scoringDrives: GAME_G2_DRIVES,
      },
      plays: GAME_G2_PLAYS,
      homeStats: GAME_G2_HOME_STATS,
      awayStats: GAME_G2_AWAY_STATS,
    };
  }

  // Generate generic mock data for any game
  return {
    game,
    boxScore: {
      gameId,
      homeTeam: game.homeTeam,
      awayTeam: game.awayTeam,
      scoringDrives: [],
    },
    plays: [],
    homeStats: {
      totalYards: 350,
      passingYards: 200,
      rushingYards: 150,
      turnovers: 1,
      penalties: 5,
      penaltyYards: 40,
      firstDowns: 18,
      thirdDownEfficiency: "5-12",
      fourthDownEfficiency: "1-2",
      timeOfPossession: "30:00",
      redZoneEfficiency: "3-4",
      sacks: 2,
      interceptions: 1,
      fumbles: 0,
    },
    awayStats: {
      totalYards: 320,
      passingYards: 190,
      rushingYards: 130,
      turnovers: 2,
      penalties: 6,
      penaltyYards: 50,
      firstDowns: 16,
      thirdDownEfficiency: "4-11",
      fourthDownEfficiency: "0-1",
      timeOfPossession: "30:00",
      redZoneEfficiency: "2-3",
      sacks: 1,
      interceptions: 1,
      fumbles: 1,
    },
  };
}
