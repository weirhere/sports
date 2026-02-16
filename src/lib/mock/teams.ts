import type { Team } from "@/lib/types";
import { ESPN_LOGO_BASE } from "@/lib/constants";

function logo(espnId: number) {
  return `${ESPN_LOGO_BASE}/${espnId}.png`;
}

// Subset of FBS teams for mock data — covers Power 4 + key Group of 5
export const MOCK_TEAMS: Team[] = [
  // SEC
  { id: "t-1", espnId: 333, name: "Crimson Tide", school: "Alabama", abbreviation: "ALA", conferenceId: "8", conferenceName: "SEC", division: "FBS", color: "#9E1B32", altColor: "#FFFFFF", logoUrl: logo(333) },
  { id: "t-2", espnId: 2032, name: "Tigers", school: "Auburn", abbreviation: "AUB", conferenceId: "8", conferenceName: "SEC", division: "FBS", color: "#03244D", altColor: "#F26522", logoUrl: logo(2032) },
  { id: "t-3", espnId: 96, name: "Bulldogs", school: "Georgia", abbreviation: "UGA", conferenceId: "8", conferenceName: "SEC", division: "FBS", color: "#BA0C2F", altColor: "#000000", logoUrl: logo(96) },
  { id: "t-4", espnId: 2633, name: "Volunteers", school: "Tennessee", abbreviation: "TENN", conferenceId: "8", conferenceName: "SEC", division: "FBS", color: "#FF8200", altColor: "#FFFFFF", logoUrl: logo(2633) },
  { id: "t-5", espnId: 2305, name: "Rebels", school: "Ole Miss", abbreviation: "MISS", conferenceId: "8", conferenceName: "SEC", division: "FBS", color: "#CE1126", altColor: "#14213D", logoUrl: logo(2305) },
  { id: "t-6", espnId: 127, name: "Aggies", school: "Texas A&M", abbreviation: "TAMU", conferenceId: "8", conferenceName: "SEC", division: "FBS", color: "#500000", altColor: "#FFFFFF", logoUrl: logo(127) },
  { id: "t-7", espnId: 99, name: "Tigers", school: "LSU", abbreviation: "LSU", conferenceId: "8", conferenceName: "SEC", division: "FBS", color: "#461D7C", altColor: "#FDD023", logoUrl: logo(99) },
  { id: "t-8", espnId: 57, name: "Gators", school: "Florida", abbreviation: "FLA", conferenceId: "8", conferenceName: "SEC", division: "FBS", color: "#0021A5", altColor: "#FA4616", logoUrl: logo(57) },
  { id: "t-9", espnId: 251, name: "Longhorns", school: "Texas", abbreviation: "TEX", conferenceId: "8", conferenceName: "SEC", division: "FBS", color: "#BF5700", altColor: "#FFFFFF", logoUrl: logo(251) },
  { id: "t-10", espnId: 145, name: "Sooners", school: "Oklahoma", abbreviation: "OU", conferenceId: "8", conferenceName: "SEC", division: "FBS", color: "#841617", altColor: "#FDF9D8", logoUrl: logo(145) },

  // Big Ten
  { id: "t-11", espnId: 194, name: "Buckeyes", school: "Ohio State", abbreviation: "OSU", conferenceId: "5", conferenceName: "Big Ten", division: "FBS", color: "#BB0000", altColor: "#666666", logoUrl: logo(194) },
  { id: "t-12", espnId: 130, name: "Wolverines", school: "Michigan", abbreviation: "MICH", conferenceId: "5", conferenceName: "Big Ten", division: "FBS", color: "#00274C", altColor: "#FFCB05", logoUrl: logo(130) },
  { id: "t-13", espnId: 213, name: "Nittany Lions", school: "Penn State", abbreviation: "PSU", conferenceId: "5", conferenceName: "Big Ten", division: "FBS", color: "#041E42", altColor: "#FFFFFF", logoUrl: logo(213) },
  { id: "t-14", espnId: 356, name: "Trojans", school: "USC", abbreviation: "USC", conferenceId: "5", conferenceName: "Big Ten", division: "FBS", color: "#990000", altColor: "#FFC72C", logoUrl: logo(356) },
  { id: "t-15", espnId: 264, name: "Ducks", school: "Oregon", abbreviation: "ORE", conferenceId: "5", conferenceName: "Big Ten", division: "FBS", color: "#154733", altColor: "#FEE123", logoUrl: logo(264) },
  { id: "t-16", espnId: 275, name: "Badgers", school: "Wisconsin", abbreviation: "WIS", conferenceId: "5", conferenceName: "Big Ten", division: "FBS", color: "#C5050C", altColor: "#FFFFFF", logoUrl: logo(275) },
  { id: "t-17", espnId: 2294, name: "Hawkeyes", school: "Iowa", abbreviation: "IOWA", conferenceId: "5", conferenceName: "Big Ten", division: "FBS", color: "#FFCD00", altColor: "#000000", logoUrl: logo(2294) },

  // ACC
  { id: "t-18", espnId: 228, name: "Seminoles", school: "Florida State", abbreviation: "FSU", conferenceId: "1", conferenceName: "ACC", division: "FBS", color: "#782F40", altColor: "#CEB888", logoUrl: logo(228) },
  { id: "t-19", espnId: 2390, name: "Tigers", school: "Clemson", abbreviation: "CLEM", conferenceId: "1", conferenceName: "ACC", division: "FBS", color: "#F56600", altColor: "#522D80", logoUrl: logo(2390) },
  { id: "t-20", espnId: 2628, name: "Hurricanes", school: "Miami", abbreviation: "MIA", conferenceId: "1", conferenceName: "ACC", division: "FBS", color: "#F47321", altColor: "#005030", logoUrl: logo(2628) },
  { id: "t-21", espnId: 59, name: "Tar Heels", school: "North Carolina", abbreviation: "UNC", conferenceId: "1", conferenceName: "ACC", division: "FBS", color: "#7BAFD4", altColor: "#13294B", logoUrl: logo(59) },
  { id: "t-22", espnId: 2579, name: "Cardinals", school: "Louisville", abbreviation: "LOU", conferenceId: "1", conferenceName: "ACC", division: "FBS", color: "#AD0000", altColor: "#000000", logoUrl: logo(2579) },

  // Big 12
  { id: "t-23", espnId: 2628, name: "Wildcats", school: "Arizona", abbreviation: "ARIZ", conferenceId: "4", conferenceName: "Big 12", division: "FBS", color: "#CC0033", altColor: "#003366", logoUrl: logo(12) },
  { id: "t-24", espnId: 2005, name: "Sun Devils", school: "Arizona State", abbreviation: "ASU", conferenceId: "4", conferenceName: "Big 12", division: "FBS", color: "#8C1D40", altColor: "#FFC627", logoUrl: logo(2005) },
  { id: "t-25", espnId: 2132, name: "Cougars", school: "BYU", abbreviation: "BYU", conferenceId: "4", conferenceName: "Big 12", division: "FBS", color: "#002E5D", altColor: "#FFFFFF", logoUrl: logo(252) },
  { id: "t-26", espnId: 2305, name: "Buffaloes", school: "Colorado", abbreviation: "COLO", conferenceId: "4", conferenceName: "Big 12", division: "FBS", color: "#CFB87C", altColor: "#000000", logoUrl: logo(38) },
  { id: "t-27", espnId: 66, name: "Bears", school: "Baylor", abbreviation: "BAY", conferenceId: "4", conferenceName: "Big 12", division: "FBS", color: "#154734", altColor: "#FFB81C", logoUrl: logo(239) },

  // Pac-12 (rebuilt)
  { id: "t-28", espnId: 265, name: "Beavers", school: "Oregon State", abbreviation: "ORST", conferenceId: "9", conferenceName: "Pac-12", division: "FBS", color: "#DC4405", altColor: "#000000", logoUrl: logo(204) },
  { id: "t-29", espnId: 2483, name: "Cougars", school: "Washington State", abbreviation: "WSU", conferenceId: "9", conferenceName: "Pac-12", division: "FBS", color: "#981E32", altColor: "#5E6A71", logoUrl: logo(265) },

  // Group of 5
  { id: "t-30", espnId: 2116, name: "Broncos", school: "Boise State", abbreviation: "BSU", conferenceId: "17", conferenceName: "MWC", division: "FBS", color: "#0033A0", altColor: "#D64309", logoUrl: logo(68) },
  { id: "t-31", espnId: 2653, name: "Bulldogs", school: "Liberty", abbreviation: "LIB", conferenceId: "12", conferenceName: "C-USA", division: "FBS", color: "#002D62", altColor: "#C41230", logoUrl: logo(2335) },
  { id: "t-32", espnId: 2229, name: "Wildcats", school: "Tulane", abbreviation: "TULN", conferenceId: "151", conferenceName: "AAC", division: "FBS", color: "#006747", altColor: "#87CEEB", logoUrl: logo(2655) },

  // Independents
  { id: "t-33", espnId: 87, name: "Fighting Irish", school: "Notre Dame", abbreviation: "ND", conferenceId: "18", conferenceName: "FBS Independents", division: "FBS", color: "#0C2340", altColor: "#C99700", logoUrl: logo(87) },
  { id: "t-34", espnId: 2, name: "Black Knights", school: "Army", abbreviation: "ARMY", conferenceId: "18", conferenceName: "FBS Independents", division: "FBS", color: "#000000", altColor: "#D2B48C", logoUrl: logo(349) },
];

export function getTeamById(id: string): Team | undefined {
  return MOCK_TEAMS.find((t) => t.id === id);
}

export function getTeamsByConference(conferenceId: string): Team[] {
  return MOCK_TEAMS.filter((t) => t.conferenceId === conferenceId);
}
