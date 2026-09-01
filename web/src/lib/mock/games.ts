import type { Game } from "@/lib/types";
import { MOCK_TEAMS } from "./teams";

function team(id: string) {
  const t = MOCK_TEAMS.find((t) => t.id === id);
  if (!t) throw new Error(`Mock team not found: ${id}`);
  return t;
}

// Mock games for Week 8 — a typical Saturday slate
export const MOCK_GAMES: Game[] = [
  // === SATURDAY GAMES ===

  // SEC: #3 Georgia vs #8 Texas (live game)
  {
    id: "g-1",
    status: "in_progress",
    scheduledAt: "2025-10-18T19:30:00Z",
    venue: { name: "Darrell K Royal Stadium", city: "Austin", state: "TX" },
    homeTeam: {
      team: team("t-9"),
      score: 21,
      ranking: 8,
      record: "6-1",
      isWinner: false,
      linescores: [7, 7, 7],
    },
    awayTeam: {
      team: team("t-3"),
      score: 24,
      ranking: 3,
      record: "7-0",
      isWinner: false,
      linescores: [10, 7, 7],
    },
    broadcast: "CBS",
    clock: "4:22",
    quarter: 3,
    possession: "home",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // SEC: #12 Tennessee vs Alabama
  {
    id: "g-2",
    status: "complete",
    scheduledAt: "2025-10-18T16:00:00Z",
    venue: { name: "Bryant-Denny Stadium", city: "Tuscaloosa", state: "AL" },
    homeTeam: {
      team: team("t-1"),
      score: 28,
      record: "5-2",
      isWinner: true,
      linescores: [7, 14, 0, 7],
    },
    awayTeam: {
      team: team("t-4"),
      score: 24,
      ranking: 12,
      record: "5-2",
      isWinner: false,
      linescores: [7, 3, 7, 7],
    },
    broadcast: "ESPN",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // SEC: LSU vs Ole Miss (upcoming evening)
  {
    id: "g-3",
    status: "scheduled",
    scheduledAt: "2025-10-18T23:00:00Z",
    venue: { name: "Vaught-Hemingway Stadium", city: "Oxford", state: "MS" },
    homeTeam: {
      team: team("t-5"),
      score: null,
      ranking: 15,
      record: "5-2",
    },
    awayTeam: {
      team: team("t-7"),
      score: null,
      record: "4-3",
    },
    broadcast: "ESPN2",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // SEC: Florida vs Auburn
  {
    id: "g-4",
    status: "complete",
    scheduledAt: "2025-10-18T16:00:00Z",
    venue: { name: "Jordan-Hare Stadium", city: "Auburn", state: "AL" },
    homeTeam: {
      team: team("t-2"),
      score: 17,
      record: "3-4",
      isWinner: false,
      linescores: [7, 3, 0, 7],
    },
    awayTeam: {
      team: team("t-8"),
      score: 20,
      record: "4-3",
      isWinner: true,
      linescores: [3, 7, 3, 7],
    },
    broadcast: "SEC Network",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // SEC: Texas A&M vs Oklahoma
  {
    id: "g-5",
    status: "in_progress",
    scheduledAt: "2025-10-18T19:30:00Z",
    venue: {
      name: "Gaylord Family Stadium",
      city: "Norman",
      state: "OK",
    },
    homeTeam: {
      team: team("t-10"),
      score: 14,
      record: "4-3",
      isWinner: false,
      linescores: [7, 7],
    },
    awayTeam: {
      team: team("t-6"),
      score: 10,
      ranking: 18,
      record: "5-2",
      isWinner: false,
      linescores: [3, 7],
    },
    broadcast: "ABC",
    clock: "0:45",
    quarter: 2,
    possession: "away",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // Big Ten: #2 Ohio State vs #13 Penn State
  {
    id: "g-6",
    status: "in_progress",
    scheduledAt: "2025-10-18T20:00:00Z",
    venue: { name: "Beaver Stadium", city: "State College", state: "PA" },
    homeTeam: {
      team: team("t-13"),
      score: 17,
      ranking: 13,
      record: "6-1",
      isWinner: false,
      linescores: [7, 10],
    },
    awayTeam: {
      team: team("t-11"),
      score: 14,
      ranking: 2,
      record: "7-0",
      isWinner: false,
      linescores: [7, 7],
    },
    broadcast: "FOX",
    clock: "12:30",
    quarter: 3,
    possession: "home",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // Big Ten: Michigan vs Iowa
  {
    id: "g-7",
    status: "complete",
    scheduledAt: "2025-10-18T16:00:00Z",
    venue: { name: "Michigan Stadium", city: "Ann Arbor", state: "MI" },
    homeTeam: {
      team: team("t-12"),
      score: 10,
      record: "4-3",
      isWinner: true,
      linescores: [0, 3, 7, 0],
    },
    awayTeam: {
      team: team("t-17"),
      score: 6,
      record: "4-3",
      isWinner: false,
      linescores: [3, 0, 3, 0],
    },
    broadcast: "Big Ten Network",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // Big Ten: #5 Oregon vs Wisconsin
  {
    id: "g-8",
    status: "scheduled",
    scheduledAt: "2025-10-18T23:30:00Z",
    venue: { name: "Autzen Stadium", city: "Eugene", state: "OR" },
    homeTeam: {
      team: team("t-15"),
      score: null,
      ranking: 5,
      record: "7-0",
    },
    awayTeam: {
      team: team("t-16"),
      score: null,
      record: "4-3",
    },
    broadcast: "NBC",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // Big Ten: USC (bye in this mock — not included)

  // ACC: #10 Miami vs Louisville
  {
    id: "g-9",
    status: "complete",
    scheduledAt: "2025-10-18T16:00:00Z",
    venue: { name: "Cardinal Stadium", city: "Louisville", state: "KY" },
    homeTeam: {
      team: team("t-22"),
      score: 21,
      record: "4-3",
      isWinner: false,
      linescores: [7, 0, 7, 7],
    },
    awayTeam: {
      team: team("t-20"),
      score: 35,
      ranking: 10,
      record: "7-0",
      isWinner: true,
      linescores: [14, 7, 7, 7],
    },
    broadcast: "ABC",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // ACC: Clemson vs Florida State
  {
    id: "g-10",
    status: "scheduled",
    scheduledAt: "2025-10-18T23:00:00Z",
    venue: { name: "Doak Campbell Stadium", city: "Tallahassee", state: "FL" },
    homeTeam: {
      team: team("t-18"),
      score: null,
      record: "2-5",
    },
    awayTeam: {
      team: team("t-19"),
      score: null,
      ranking: 20,
      record: "5-2",
    },
    broadcast: "ACC Network",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // Big 12: Arizona State vs BYU
  {
    id: "g-11",
    status: "complete",
    scheduledAt: "2025-10-18T18:00:00Z",
    venue: { name: "LaVell Edwards Stadium", city: "Provo", state: "UT" },
    homeTeam: {
      team: team("t-25"),
      score: 28,
      ranking: 22,
      record: "6-1",
      isWinner: true,
      linescores: [7, 7, 7, 7],
    },
    awayTeam: {
      team: team("t-24"),
      score: 21,
      ranking: 24,
      record: "5-2",
      isWinner: false,
      linescores: [7, 7, 0, 7],
    },
    broadcast: "FOX",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // Big 12: Colorado vs Baylor
  {
    id: "g-12",
    status: "scheduled",
    scheduledAt: "2025-10-18T23:00:00Z",
    venue: { name: "Folsom Field", city: "Boulder", state: "CO" },
    homeTeam: {
      team: team("t-26"),
      score: null,
      record: "5-2",
    },
    awayTeam: {
      team: team("t-27"),
      score: null,
      record: "3-4",
    },
    broadcast: "ESPN+",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // Independents: #7 Notre Dame vs USC
  {
    id: "g-13",
    status: "in_progress",
    scheduledAt: "2025-10-18T19:30:00Z",
    venue: { name: "Notre Dame Stadium", city: "South Bend", state: "IN" },
    homeTeam: {
      team: team("t-33"),
      score: 28,
      ranking: 7,
      record: "6-1",
      isWinner: false,
      linescores: [7, 14, 7],
    },
    awayTeam: {
      team: team("t-14"),
      score: 21,
      record: "4-3",
      isWinner: false,
      linescores: [7, 7, 7],
    },
    broadcast: "NBC",
    clock: "8:15",
    quarter: 3,
    possession: "away",
    week: 8,
    seasonYear: 2025,
    conferenceGame: false,
  },

  // MWC: Boise State (no opponent in our mock subset — standalone)
  {
    id: "g-14",
    status: "complete",
    scheduledAt: "2025-10-18T18:00:00Z",
    venue: { name: "Albertsons Stadium", city: "Boise", state: "ID" },
    homeTeam: {
      team: team("t-30"),
      score: 42,
      ranking: 14,
      record: "6-1",
      isWinner: true,
      linescores: [14, 14, 7, 7],
    },
    awayTeam: {
      team: {
        id: "t-opp1",
        espnId: 2440,
        name: "Rebels",
        school: "UNLV",
        abbreviation: "UNLV",
        conferenceId: "17",
        conferenceName: "MWC",
        division: "FBS",
        color: "#CF0A2C",
        logoUrl: "https://a.espncdn.com/i/teamlogos/ncaa/500/2439.png",
      },
      score: 21,
      record: "4-3",
      isWinner: false,
      linescores: [7, 7, 0, 7],
    },
    broadcast: "FS1",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },

  // === FRIDAY NIGHT GAME ===
  // ACC: North Carolina vs an opponent
  {
    id: "g-15",
    status: "complete",
    scheduledAt: "2025-10-17T23:30:00Z",
    venue: { name: "Kenan Memorial Stadium", city: "Chapel Hill", state: "NC" },
    homeTeam: {
      team: team("t-21"),
      score: 31,
      record: "4-3",
      isWinner: true,
      linescores: [7, 10, 7, 7],
    },
    awayTeam: {
      team: {
        id: "t-opp2",
        espnId: 258,
        name: "Cavaliers",
        school: "Virginia",
        abbreviation: "UVA",
        conferenceId: "1",
        conferenceName: "ACC",
        division: "FBS",
        color: "#232D4B",
        logoUrl: "https://a.espncdn.com/i/teamlogos/ncaa/500/258.png",
      },
      score: 17,
      record: "3-4",
      isWinner: false,
      linescores: [7, 3, 0, 7],
    },
    broadcast: "ESPN",
    week: 8,
    seasonYear: 2025,
    conferenceGame: true,
  },
];

export function getGamesByWeek(week: number): Game[] {
  return MOCK_GAMES.filter((g) => g.week === week);
}

export function getGameById(id: string): Game | undefined {
  return MOCK_GAMES.find((g) => g.id === id);
}

export function getGamesByTeam(teamId: string): Game[] {
  return MOCK_GAMES.filter(
    (g) => g.homeTeam.team.id === teamId || g.awayTeam.team.id === teamId
  );
}
