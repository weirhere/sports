import type { RankedTeam } from "@/lib/types";
import { MOCK_TEAMS } from "./teams";

function ranked(
  teamId: string,
  rank: number,
  record: string,
  previousRank?: number,
  votes: number = 0
): RankedTeam {
  const team = MOCK_TEAMS.find((t) => t.id === teamId)!;
  return { rank, team, record, previousRank, votes };
}

export const MOCK_RANKINGS: RankedTeam[] = [
  ranked("t-15", 1, "7-0", 1, 1525),    // Oregon
  ranked("t-11", 2, "7-0", 2, 1498),    // Ohio State
  ranked("t-3", 3, "7-0", 3, 1472),     // Georgia
  ranked("t-33", 4, "7-0", undefined, 1200), // Notre Dame — not ranked before but should be
  ranked("t-15", 5, "7-0", 4, 1350),    // Oregon (duplicate — fix)
  ranked("t-9", 6, "6-1", 5, 1200),     // Texas
  ranked("t-33", 7, "6-1", 6, 1150),    // Notre Dame
  ranked("t-9", 8, "6-1", 7, 1100),     // Texas
  ranked("t-20", 10, "7-0", 11, 950),   // Miami
  ranked("t-4", 12, "5-2", 10, 800),    // Tennessee
  ranked("t-13", 13, "6-1", 14, 750),   // Penn State
  ranked("t-30", 14, "6-1", 13, 720),   // Boise State
  ranked("t-5", 15, "5-2", 16, 680),    // Ole Miss
  ranked("t-6", 18, "5-2", 19, 500),    // Texas A&M
  ranked("t-19", 20, "5-2", 21, 400),   // Clemson
  ranked("t-25", 22, "6-1", 23, 300),   // BYU
  ranked("t-24", 24, "5-2", 25, 200),   // Arizona State
];

// De-duplicate and create a clean Top 25
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

export function getRankings(): RankedTeam[] {
  return MOCK_TOP_25;
}
