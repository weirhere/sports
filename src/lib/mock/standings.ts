import type { ConferenceStanding } from "@/lib/types";
import { MOCK_TEAMS, getTeamsByConference } from "./teams";

function standing(
  teamId: string,
  confWins: number,
  confLosses: number,
  overallWins: number,
  overallLosses: number,
  rank: number,
  streakType?: "W" | "L",
  streakLength?: number
): ConferenceStanding {
  const team = MOCK_TEAMS.find((t) => t.id === teamId)!;
  return {
    team,
    conferenceWins: confWins,
    conferenceLosses: confLosses,
    overallWins: overallWins,
    overallLosses: overallLosses,
    conferenceRank: rank,
    streakType,
    streakLength,
  };
}

export const MOCK_STANDINGS: Record<string, ConferenceStanding[]> = {
  // SEC standings
  "8": [
    standing("t-3", 5, 0, 7, 0, 1, "W", 7),
    standing("t-9", 4, 1, 6, 1, 2, "L", 1),
    standing("t-6", 4, 1, 5, 2, 3, "W", 2),
    standing("t-5", 3, 2, 5, 2, 4, "W", 1),
    standing("t-4", 3, 2, 5, 2, 5, "L", 1),
    standing("t-1", 3, 2, 5, 2, 6, "W", 1),
    standing("t-7", 2, 3, 4, 3, 7, "L", 2),
    standing("t-8", 2, 3, 4, 3, 8, "W", 1),
    standing("t-10", 1, 4, 4, 3, 9, "L", 1),
    standing("t-2", 1, 4, 3, 4, 10, "L", 3),
  ],

  // Big Ten standings
  "5": [
    standing("t-15", 5, 0, 7, 0, 1, "W", 7),
    standing("t-11", 5, 0, 7, 0, 2, "W", 7),
    standing("t-13", 4, 1, 6, 1, 3, "W", 3),
    standing("t-14", 2, 3, 4, 3, 4, "L", 1),
    standing("t-12", 2, 3, 4, 3, 5, "W", 1),
    standing("t-16", 2, 3, 4, 3, 6, "L", 2),
    standing("t-17", 2, 3, 4, 3, 7, "L", 1),
  ],

  // ACC standings
  "1": [
    standing("t-20", 5, 0, 7, 0, 1, "W", 7),
    standing("t-19", 3, 2, 5, 2, 2, "W", 2),
    standing("t-22", 2, 3, 4, 3, 3, "L", 1),
    standing("t-21", 2, 3, 4, 3, 4, "W", 1),
    standing("t-18", 0, 5, 2, 5, 5, "L", 5),
  ],

  // Big 12 standings
  "4": [
    standing("t-25", 4, 1, 6, 1, 1, "W", 4),
    standing("t-26", 3, 2, 5, 2, 2, "W", 1),
    standing("t-24", 3, 2, 5, 2, 3, "L", 1),
    standing("t-23", 2, 3, 3, 4, 4, "L", 2),
    standing("t-27", 1, 4, 3, 4, 5, "L", 1),
  ],
};

export function getStandings(conferenceId: string): ConferenceStanding[] {
  return MOCK_STANDINGS[conferenceId] || [];
}
