// Legacy route-facing bridge (client.ts) plus the domain provider.
export {
  getGameSummary,
  getRankings,
  getAllRankings,
  getStandings,
} from "./client";
export {
  scoreboard,
  rankings,
  fbsConferences,
  conferenceStandings,
  teamSchedule,
  conferenceGames,
  gameSummary,
  EspnApiError,
  EspnDataError,
} from "./provider";
