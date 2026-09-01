import type { RankedTeam, RankingsData } from "@/lib/types";
import { MOCK_TEAMS } from "./teams";

export const MOCK_TOP_25: RankedTeam[] = [
  { rank: 1, team: MOCK_TEAMS.find((t) => t.id === "t-15")!, record: "7-0", previousRank: 1, votes: 1525 },
  { rank: 2, team: MOCK_TEAMS.find((t) => t.id === "t-11")!, record: "7-0", previousRank: 2, votes: 1498 },
  { rank: 3, team: MOCK_TEAMS.find((t) => t.id === "t-3")!, record: "7-0", previousRank: 3, votes: 1472 },
  { rank: 4, team: MOCK_TEAMS.find((t) => t.id === "t-33")!, record: "6-1", previousRank: 5, votes: 1350 },
  { rank: 5, team: MOCK_TEAMS.find((t) => t.id === "t-9")!, record: "6-1", previousRank: 4, votes: 1300 },
  { rank: 6, team: MOCK_TEAMS.find((t) => t.id === "t-20")!, record: "7-0", previousRank: 8, votes: 1200 },
  { rank: 7, team: MOCK_TEAMS.find((t) => t.id === "t-1")!, record: "5-2", previousRank: 6, votes: 1100 },
  { rank: 8, team: MOCK_TEAMS.find((t) => t.id === "t-13")!, record: "6-1", previousRank: 9, votes: 1050 },
  { rank: 9, team: MOCK_TEAMS.find((t) => t.id === "t-6")!, record: "5-2", previousRank: 7, votes: 1000 },
  { rank: 10, team: MOCK_TEAMS.find((t) => t.id === "t-4")!, record: "5-2", previousRank: 10, votes: 950 },
  { rank: 11, team: MOCK_TEAMS.find((t) => t.id === "t-5")!, record: "5-2", previousRank: 11, votes: 900 },
  { rank: 12, team: MOCK_TEAMS.find((t) => t.id === "t-30")!, record: "6-1", previousRank: 12, votes: 850 },
  { rank: 13, team: MOCK_TEAMS.find((t) => t.id === "t-7")!, record: "4-3", previousRank: 13, votes: 800 },
  { rank: 14, team: MOCK_TEAMS.find((t) => t.id === "t-19")!, record: "5-2", previousRank: 15, votes: 750 },
  { rank: 15, team: MOCK_TEAMS.find((t) => t.id === "t-25")!, record: "6-1", previousRank: 16, votes: 700 },
  { rank: 16, team: MOCK_TEAMS.find((t) => t.id === "t-12")!, record: "4-3", previousRank: 14, votes: 650 },
  { rank: 17, team: MOCK_TEAMS.find((t) => t.id === "t-24")!, record: "5-2", previousRank: 18, votes: 600 },
  { rank: 18, team: MOCK_TEAMS.find((t) => t.id === "t-14")!, record: "4-3", previousRank: 17, votes: 550 },
  { rank: 19, team: MOCK_TEAMS.find((t) => t.id === "t-26")!, record: "5-2", previousRank: 20, votes: 500 },
  { rank: 20, team: MOCK_TEAMS.find((t) => t.id === "t-22")!, record: "4-3", previousRank: 22, votes: 450 },
  { rank: 21, team: MOCK_TEAMS.find((t) => t.id === "t-10")!, record: "4-3", previousRank: 19, votes: 400 },
  { rank: 22, team: MOCK_TEAMS.find((t) => t.id === "t-17")!, record: "4-3", previousRank: 21, votes: 350 },
  { rank: 23, team: MOCK_TEAMS.find((t) => t.id === "t-27")!, record: "3-4", previousRank: 24, votes: 300 },
  { rank: 24, team: MOCK_TEAMS.find((t) => t.id === "t-8")!, record: "4-3", previousRank: 23, votes: 250 },
  { rank: 25, team: MOCK_TEAMS.find((t) => t.id === "t-34")!, record: "5-1", previousRank: 25, votes: 200 },
];

// Coaches' Poll — similar to AP with slight variations in ordering
export const MOCK_COACHES_POLL: RankedTeam[] = [
  { rank: 1, team: MOCK_TEAMS.find((t) => t.id === "t-15")!, record: "7-0", previousRank: 1, votes: 1600 },
  { rank: 2, team: MOCK_TEAMS.find((t) => t.id === "t-3")!, record: "7-0", previousRank: 2, votes: 1550 },
  { rank: 3, team: MOCK_TEAMS.find((t) => t.id === "t-11")!, record: "7-0", previousRank: 3, votes: 1480 },
  { rank: 4, team: MOCK_TEAMS.find((t) => t.id === "t-9")!, record: "6-1", previousRank: 4, votes: 1350 },
  { rank: 5, team: MOCK_TEAMS.find((t) => t.id === "t-33")!, record: "6-1", previousRank: 6, votes: 1300 },
  { rank: 6, team: MOCK_TEAMS.find((t) => t.id === "t-20")!, record: "7-0", previousRank: 7, votes: 1200 },
  { rank: 7, team: MOCK_TEAMS.find((t) => t.id === "t-13")!, record: "6-1", previousRank: 8, votes: 1100 },
  { rank: 8, team: MOCK_TEAMS.find((t) => t.id === "t-1")!, record: "5-2", previousRank: 5, votes: 1050 },
  { rank: 9, team: MOCK_TEAMS.find((t) => t.id === "t-6")!, record: "5-2", previousRank: 9, votes: 1000 },
  { rank: 10, team: MOCK_TEAMS.find((t) => t.id === "t-5")!, record: "5-2", previousRank: 10, votes: 950 },
  { rank: 11, team: MOCK_TEAMS.find((t) => t.id === "t-4")!, record: "5-2", previousRank: 11, votes: 900 },
  { rank: 12, team: MOCK_TEAMS.find((t) => t.id === "t-30")!, record: "6-1", previousRank: 12, votes: 850 },
  { rank: 13, team: MOCK_TEAMS.find((t) => t.id === "t-19")!, record: "5-2", previousRank: 14, votes: 800 },
  { rank: 14, team: MOCK_TEAMS.find((t) => t.id === "t-7")!, record: "4-3", previousRank: 13, votes: 750 },
  { rank: 15, team: MOCK_TEAMS.find((t) => t.id === "t-25")!, record: "6-1", previousRank: 15, votes: 700 },
  { rank: 16, team: MOCK_TEAMS.find((t) => t.id === "t-24")!, record: "5-2", previousRank: 17, votes: 650 },
  { rank: 17, team: MOCK_TEAMS.find((t) => t.id === "t-12")!, record: "4-3", previousRank: 16, votes: 600 },
  { rank: 18, team: MOCK_TEAMS.find((t) => t.id === "t-14")!, record: "4-3", previousRank: 18, votes: 550 },
  { rank: 19, team: MOCK_TEAMS.find((t) => t.id === "t-26")!, record: "5-2", previousRank: 19, votes: 500 },
  { rank: 20, team: MOCK_TEAMS.find((t) => t.id === "t-10")!, record: "4-3", previousRank: 20, votes: 450 },
  { rank: 21, team: MOCK_TEAMS.find((t) => t.id === "t-22")!, record: "4-3", previousRank: 21, votes: 400 },
  { rank: 22, team: MOCK_TEAMS.find((t) => t.id === "t-17")!, record: "4-3", previousRank: 22, votes: 350 },
  { rank: 23, team: MOCK_TEAMS.find((t) => t.id === "t-8")!, record: "4-3", previousRank: 23, votes: 300 },
  { rank: 24, team: MOCK_TEAMS.find((t) => t.id === "t-27")!, record: "3-4", previousRank: 24, votes: 250 },
  { rank: 25, team: MOCK_TEAMS.find((t) => t.id === "t-34")!, record: "5-1", previousRank: 25, votes: 200 },
];

// CFP Rankings — top 12 playoff rankings, different order than AP/Coaches
export const MOCK_CFP_RANKINGS: RankedTeam[] = [
  { rank: 1, team: MOCK_TEAMS.find((t) => t.id === "t-11")!, record: "7-0", previousRank: 2, votes: 0 },
  { rank: 2, team: MOCK_TEAMS.find((t) => t.id === "t-15")!, record: "7-0", previousRank: 1, votes: 0 },
  { rank: 3, team: MOCK_TEAMS.find((t) => t.id === "t-9")!, record: "6-1", previousRank: 4, votes: 0 },
  { rank: 4, team: MOCK_TEAMS.find((t) => t.id === "t-3")!, record: "7-0", previousRank: 3, votes: 0 },
  { rank: 5, team: MOCK_TEAMS.find((t) => t.id === "t-33")!, record: "6-1", previousRank: 5, votes: 0 },
  { rank: 6, team: MOCK_TEAMS.find((t) => t.id === "t-20")!, record: "7-0", previousRank: 7, votes: 0 },
  { rank: 7, team: MOCK_TEAMS.find((t) => t.id === "t-13")!, record: "6-1", previousRank: 8, votes: 0 },
  { rank: 8, team: MOCK_TEAMS.find((t) => t.id === "t-1")!, record: "5-2", previousRank: 6, votes: 0 },
  { rank: 9, team: MOCK_TEAMS.find((t) => t.id === "t-4")!, record: "5-2", previousRank: 10, votes: 0 },
  { rank: 10, team: MOCK_TEAMS.find((t) => t.id === "t-5")!, record: "5-2", previousRank: 9, votes: 0 },
  { rank: 11, team: MOCK_TEAMS.find((t) => t.id === "t-6")!, record: "5-2", previousRank: 12, votes: 0 },
  { rank: 12, team: MOCK_TEAMS.find((t) => t.id === "t-30")!, record: "6-1", previousRank: 11, votes: 0 },
  { rank: 13, team: MOCK_TEAMS.find((t) => t.id === "t-25")!, record: "6-1", previousRank: 14, votes: 0 },
  { rank: 14, team: MOCK_TEAMS.find((t) => t.id === "t-19")!, record: "5-2", previousRank: 13, votes: 0 },
  { rank: 15, team: MOCK_TEAMS.find((t) => t.id === "t-7")!, record: "4-3", previousRank: 15, votes: 0 },
  { rank: 16, team: MOCK_TEAMS.find((t) => t.id === "t-24")!, record: "5-2", previousRank: 16, votes: 0 },
  { rank: 17, team: MOCK_TEAMS.find((t) => t.id === "t-12")!, record: "4-3", previousRank: 18, votes: 0 },
  { rank: 18, team: MOCK_TEAMS.find((t) => t.id === "t-14")!, record: "4-3", previousRank: 17, votes: 0 },
  { rank: 19, team: MOCK_TEAMS.find((t) => t.id === "t-26")!, record: "5-2", previousRank: 20, votes: 0 },
  { rank: 20, team: MOCK_TEAMS.find((t) => t.id === "t-22")!, record: "4-3", previousRank: 19, votes: 0 },
  { rank: 21, team: MOCK_TEAMS.find((t) => t.id === "t-10")!, record: "4-3", previousRank: 22, votes: 0 },
  { rank: 22, team: MOCK_TEAMS.find((t) => t.id === "t-17")!, record: "4-3", previousRank: 21, votes: 0 },
  { rank: 23, team: MOCK_TEAMS.find((t) => t.id === "t-27")!, record: "3-4", previousRank: 23, votes: 0 },
  { rank: 24, team: MOCK_TEAMS.find((t) => t.id === "t-8")!, record: "4-3", previousRank: 24, votes: 0 },
  { rank: 25, team: MOCK_TEAMS.find((t) => t.id === "t-34")!, record: "5-1", previousRank: 25, votes: 0 },
];

export const MOCK_ALL_RANKINGS: RankingsData[] = [
  { type: "cfp", label: "CFB Playoff", teams: MOCK_CFP_RANKINGS },
  { type: "ap", label: "AP Poll", teams: MOCK_TOP_25 },
  { type: "coaches", label: "Coaches' Poll", teams: MOCK_COACHES_POLL },
];

export function getAllRankings(): RankingsData[] {
  return MOCK_ALL_RANKINGS;
}

export function getRankings(): RankedTeam[] {
  return MOCK_TOP_25;
}
