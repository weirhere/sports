import type { Player } from "@/lib/types";

// Notable players for each mock team (3–5 per team)
export const MOCK_PLAYERS: Player[] = [
  // SEC — Alabama
  { id: "p-1", espnId: 4432762, displayName: "Jalen Milroe", firstName: "Jalen", lastName: "Milroe", jersey: "4", position: "QB", teamId: "t-1", teamName: "Alabama" },
  { id: "p-2", espnId: 4567048, displayName: "Ryan Williams", firstName: "Ryan", lastName: "Williams", jersey: "2", position: "WR", teamId: "t-1", teamName: "Alabama" },
  { id: "p-3", espnId: 4432095, displayName: "Jam Miller", firstName: "Jam", lastName: "Miller", jersey: "26", position: "RB", teamId: "t-1", teamName: "Alabama" },

  // SEC — Auburn
  { id: "p-4", espnId: 4682930, displayName: "Payton Thorne", firstName: "Payton", lastName: "Thorne", jersey: "1", position: "QB", teamId: "t-2", teamName: "Auburn" },
  { id: "p-5", espnId: 4567123, displayName: "Jarquez Hunter", firstName: "Jarquez", lastName: "Hunter", jersey: "27", position: "RB", teamId: "t-2", teamName: "Auburn" },
  { id: "p-6", espnId: 4432455, displayName: "Camden Brown", firstName: "Camden", lastName: "Brown", jersey: "13", position: "WR", teamId: "t-2", teamName: "Auburn" },

  // SEC — Georgia
  { id: "p-7", espnId: 4432985, displayName: "Carson Beck", firstName: "Carson", lastName: "Beck", jersey: "15", position: "QB", teamId: "t-3", teamName: "Georgia" },
  { id: "p-8", espnId: 4567891, displayName: "Trevor Etienne", firstName: "Trevor", lastName: "Etienne", jersey: "1", position: "RB", teamId: "t-3", teamName: "Georgia" },
  { id: "p-9", espnId: 4432101, displayName: "Brock Bowers", firstName: "Brock", lastName: "Bowers", jersey: "19", position: "TE", teamId: "t-3", teamName: "Georgia" },

  // SEC — Tennessee
  { id: "p-10", espnId: 4432234, displayName: "Nico Iamaleava", firstName: "Nico", lastName: "Iamaleava", jersey: "8", position: "QB", teamId: "t-4", teamName: "Tennessee" },
  { id: "p-11", espnId: 4567222, displayName: "Dylan Sampson", firstName: "Dylan", lastName: "Sampson", jersey: "6", position: "RB", teamId: "t-4", teamName: "Tennessee" },
  { id: "p-12", espnId: 4432555, displayName: "Squirrel White", firstName: "Squirrel", lastName: "White", jersey: "10", position: "WR", teamId: "t-4", teamName: "Tennessee" },

  // SEC — Ole Miss
  { id: "p-13", espnId: 4361715, displayName: "Jaxson Dart", firstName: "Jaxson", lastName: "Dart", jersey: "2", position: "QB", teamId: "t-5", teamName: "Ole Miss" },
  { id: "p-14", espnId: 4567333, displayName: "Tre Harris", firstName: "Tre", lastName: "Harris", jersey: "1", position: "WR", teamId: "t-5", teamName: "Ole Miss" },
  { id: "p-15", espnId: 4432666, displayName: "Henry Parrish Jr.", firstName: "Henry", lastName: "Parrish Jr.", jersey: "21", position: "RB", teamId: "t-5", teamName: "Ole Miss" },

  // SEC — Texas A&M
  { id: "p-16", espnId: 4432345, displayName: "Conner Weigman", firstName: "Conner", lastName: "Weigman", jersey: "15", position: "QB", teamId: "t-6", teamName: "Texas A&M" },
  { id: "p-17", espnId: 4567444, displayName: "Le'Veon Moss", firstName: "Le'Veon", lastName: "Moss", jersey: "8", position: "RB", teamId: "t-6", teamName: "Texas A&M" },
  { id: "p-18", espnId: 4432777, displayName: "Evan Stewart", firstName: "Evan", lastName: "Stewart", jersey: "1", position: "WR", teamId: "t-6", teamName: "Texas A&M" },

  // SEC — LSU
  { id: "p-19", espnId: 4432456, displayName: "Garrett Nussmeier", firstName: "Garrett", lastName: "Nussmeier", jersey: "13", position: "QB", teamId: "t-7", teamName: "LSU" },
  { id: "p-20", espnId: 4567555, displayName: "John Emery Jr.", firstName: "John", lastName: "Emery Jr.", jersey: "4", position: "RB", teamId: "t-7", teamName: "LSU" },
  { id: "p-21", espnId: 4432888, displayName: "Kyren Lacy", firstName: "Kyren", lastName: "Lacy", jersey: "2", position: "WR", teamId: "t-7", teamName: "LSU" },

  // SEC — Florida
  { id: "p-22", espnId: 4432567, displayName: "Graham Mertz", firstName: "Graham", lastName: "Mertz", jersey: "15", position: "QB", teamId: "t-8", teamName: "Florida" },
  { id: "p-23", espnId: 4567666, displayName: "Montrell Johnson Jr.", firstName: "Montrell", lastName: "Johnson Jr.", jersey: "2", position: "RB", teamId: "t-8", teamName: "Florida" },
  { id: "p-24", espnId: 4432999, displayName: "Eugene Wilson III", firstName: "Eugene", lastName: "Wilson III", jersey: "3", position: "WR", teamId: "t-8", teamName: "Florida" },

  // SEC — Texas
  { id: "p-25", espnId: 4432678, displayName: "Quinn Ewers", firstName: "Quinn", lastName: "Ewers", jersey: "3", position: "QB", teamId: "t-9", teamName: "Texas" },
  { id: "p-26", espnId: 4567777, displayName: "Jonathon Brooks", firstName: "Jonathon", lastName: "Brooks", jersey: "24", position: "RB", teamId: "t-9", teamName: "Texas" },
  { id: "p-27", espnId: 4433000, displayName: "Xavier Worthy", firstName: "Xavier", lastName: "Worthy", jersey: "8", position: "WR", teamId: "t-9", teamName: "Texas" },

  // SEC — Oklahoma
  { id: "p-28", espnId: 4432789, displayName: "Jackson Arnold", firstName: "Jackson", lastName: "Arnold", jersey: "12", position: "QB", teamId: "t-10", teamName: "Oklahoma" },
  { id: "p-29", espnId: 4567888, displayName: "Gavin Sawchuk", firstName: "Gavin", lastName: "Sawchuk", jersey: "5", position: "RB", teamId: "t-10", teamName: "Oklahoma" },
  { id: "p-30", espnId: 4433111, displayName: "Nic Anderson", firstName: "Nic", lastName: "Anderson", jersey: "4", position: "WR", teamId: "t-10", teamName: "Oklahoma" },

  // Big Ten — Ohio State
  { id: "p-31", espnId: 4432890, displayName: "Will Howard", firstName: "Will", lastName: "Howard", jersey: "18", position: "QB", teamId: "t-11", teamName: "Ohio State" },
  { id: "p-32", espnId: 4567999, displayName: "TreVeyon Henderson", firstName: "TreVeyon", lastName: "Henderson", jersey: "32", position: "RB", teamId: "t-11", teamName: "Ohio State" },
  { id: "p-33", espnId: 4433222, displayName: "Emeka Egbuka", firstName: "Emeka", lastName: "Egbuka", jersey: "2", position: "WR", teamId: "t-11", teamName: "Ohio State" },
  { id: "p-34", espnId: 4433223, displayName: "Jeremiah Smith", firstName: "Jeremiah", lastName: "Smith", jersey: "4", position: "WR", teamId: "t-11", teamName: "Ohio State" },

  // Big Ten — Michigan
  { id: "p-35", espnId: 4432901, displayName: "Davis Warren", firstName: "Davis", lastName: "Warren", jersey: "16", position: "QB", teamId: "t-12", teamName: "Michigan" },
  { id: "p-36", espnId: 4568000, displayName: "Donovan Edwards", firstName: "Donovan", lastName: "Edwards", jersey: "7", position: "RB", teamId: "t-12", teamName: "Michigan" },
  { id: "p-37", espnId: 4433333, displayName: "Colston Loveland", firstName: "Colston", lastName: "Loveland", jersey: "18", position: "TE", teamId: "t-12", teamName: "Michigan" },

  // Big Ten — Penn State
  { id: "p-38", espnId: 4432912, displayName: "Drew Allar", firstName: "Drew", lastName: "Allar", jersey: "15", position: "QB", teamId: "t-13", teamName: "Penn State" },
  { id: "p-39", espnId: 4568111, displayName: "Nicholas Singleton", firstName: "Nicholas", lastName: "Singleton", jersey: "10", position: "RB", teamId: "t-13", teamName: "Penn State" },
  { id: "p-40", espnId: 4433444, displayName: "Tyler Warren", firstName: "Tyler", lastName: "Warren", jersey: "44", position: "TE", teamId: "t-13", teamName: "Penn State" },

  // Big Ten — USC
  { id: "p-41", espnId: 4432923, displayName: "Miller Moss", firstName: "Miller", lastName: "Moss", jersey: "7", position: "QB", teamId: "t-14", teamName: "USC" },
  { id: "p-42", espnId: 4568222, displayName: "Woody Marks", firstName: "Woody", lastName: "Marks", jersey: "22", position: "RB", teamId: "t-14", teamName: "USC" },
  { id: "p-43", espnId: 4433555, displayName: "Zachariah Branch", firstName: "Zachariah", lastName: "Branch", jersey: "1", position: "WR", teamId: "t-14", teamName: "USC" },

  // Big Ten — Oregon
  { id: "p-44", espnId: 4432934, displayName: "Dillon Gabriel", firstName: "Dillon", lastName: "Gabriel", jersey: "8", position: "QB", teamId: "t-15", teamName: "Oregon" },
  { id: "p-45", espnId: 4568333, displayName: "Jordan James", firstName: "Jordan", lastName: "James", jersey: "21", position: "RB", teamId: "t-15", teamName: "Oregon" },
  { id: "p-46", espnId: 4433666, displayName: "Tez Johnson", firstName: "Tez", lastName: "Johnson", jersey: "15", position: "WR", teamId: "t-15", teamName: "Oregon" },

  // Big Ten — Wisconsin
  { id: "p-47", espnId: 4432945, displayName: "Tyler Van Dyke", firstName: "Tyler", lastName: "Van Dyke", jersey: "9", position: "QB", teamId: "t-16", teamName: "Wisconsin" },
  { id: "p-48", espnId: 4568444, displayName: "Chez Mellusi", firstName: "Chez", lastName: "Mellusi", jersey: "6", position: "RB", teamId: "t-16", teamName: "Wisconsin" },

  // Big Ten — Iowa
  { id: "p-49", espnId: 4432956, displayName: "Cade McNamara", firstName: "Cade", lastName: "McNamara", jersey: "12", position: "QB", teamId: "t-17", teamName: "Iowa" },
  { id: "p-50", espnId: 4568555, displayName: "Kaleb Johnson", firstName: "Kaleb", lastName: "Johnson", jersey: "2", position: "RB", teamId: "t-17", teamName: "Iowa" },

  // ACC — Florida State
  { id: "p-51", espnId: 4432967, displayName: "DJ Uiagalelei", firstName: "DJ", lastName: "Uiagalelei", jersey: "7", position: "QB", teamId: "t-18", teamName: "Florida State" },
  { id: "p-52", espnId: 4568666, displayName: "Trey Benson", firstName: "Trey", lastName: "Benson", jersey: "3", position: "RB", teamId: "t-18", teamName: "Florida State" },

  // ACC — Clemson
  { id: "p-53", espnId: 4432978, displayName: "Cade Klubnik", firstName: "Cade", lastName: "Klubnik", jersey: "2", position: "QB", teamId: "t-19", teamName: "Clemson" },
  { id: "p-54", espnId: 4568777, displayName: "Phil Mafah", firstName: "Phil", lastName: "Mafah", jersey: "26", position: "RB", teamId: "t-19", teamName: "Clemson" },

  // ACC — Miami
  { id: "p-55", espnId: 4432989, displayName: "Cam Ward", firstName: "Cam", lastName: "Ward", jersey: "1", position: "QB", teamId: "t-20", teamName: "Miami" },
  { id: "p-56", espnId: 4568888, displayName: "Damien Martinez", firstName: "Damien", lastName: "Martinez", jersey: "6", position: "RB", teamId: "t-20", teamName: "Miami" },

  // ACC — North Carolina
  { id: "p-57", espnId: 4432990, displayName: "Drake Maye", firstName: "Drake", lastName: "Maye", jersey: "10", position: "QB", teamId: "t-21", teamName: "North Carolina" },
  { id: "p-58", espnId: 4568999, displayName: "Omarion Hampton", firstName: "Omarion", lastName: "Hampton", jersey: "28", position: "RB", teamId: "t-21", teamName: "North Carolina" },

  // ACC — Louisville
  { id: "p-59", espnId: 4433001, displayName: "Tyler Shough", firstName: "Tyler", lastName: "Shough", jersey: "12", position: "QB", teamId: "t-22", teamName: "Louisville" },
  { id: "p-60", espnId: 4569000, displayName: "Isaac Brown", firstName: "Isaac", lastName: "Brown", jersey: "1", position: "RB", teamId: "t-22", teamName: "Louisville" },

  // Big 12 — Arizona
  { id: "p-61", espnId: 4433012, displayName: "Noah Fifita", firstName: "Noah", lastName: "Fifita", jersey: "11", position: "QB", teamId: "t-23", teamName: "Arizona" },
  { id: "p-62", espnId: 4569111, displayName: "Tetairoa McMillan", firstName: "Tetairoa", lastName: "McMillan", jersey: "4", position: "WR", teamId: "t-23", teamName: "Arizona" },

  // Big 12 — Arizona State
  { id: "p-63", espnId: 4433023, displayName: "Sam Leavitt", firstName: "Sam", lastName: "Leavitt", jersey: "8", position: "QB", teamId: "t-24", teamName: "Arizona State" },
  { id: "p-64", espnId: 4569222, displayName: "Cam Skattebo", firstName: "Cam", lastName: "Skattebo", jersey: "4", position: "RB", teamId: "t-24", teamName: "Arizona State" },

  // Big 12 — BYU
  { id: "p-65", espnId: 4433034, displayName: "Jake Retzlaff", firstName: "Jake", lastName: "Retzlaff", jersey: "12", position: "QB", teamId: "t-25", teamName: "BYU" },
  { id: "p-66", espnId: 4569333, displayName: "LJ Martin", firstName: "LJ", lastName: "Martin", jersey: "27", position: "RB", teamId: "t-25", teamName: "BYU" },

  // Big 12 — Colorado
  { id: "p-67", espnId: 4433045, displayName: "Shedeur Sanders", firstName: "Shedeur", lastName: "Sanders", jersey: "2", position: "QB", teamId: "t-26", teamName: "Colorado" },
  { id: "p-68", espnId: 4569444, displayName: "Travis Hunter", firstName: "Travis", lastName: "Hunter", jersey: "12", position: "WR", teamId: "t-26", teamName: "Colorado" },

  // Big 12 — Baylor
  { id: "p-69", espnId: 4433056, displayName: "Sawyer Robertson", firstName: "Sawyer", lastName: "Robertson", jersey: "12", position: "QB", teamId: "t-27", teamName: "Baylor" },
  { id: "p-70", espnId: 4569555, displayName: "Richard Reese", firstName: "Richard", lastName: "Reese", jersey: "29", position: "RB", teamId: "t-27", teamName: "Baylor" },

  // Pac-12 — Oregon State
  { id: "p-71", espnId: 4433067, displayName: "DJ Uiagalelei", firstName: "Gevani", lastName: "McCoy", jersey: "3", position: "QB", teamId: "t-28", teamName: "Oregon State" },

  // Pac-12 — Washington State
  { id: "p-72", espnId: 4433078, displayName: "John Mateer", firstName: "John", lastName: "Mateer", jersey: "10", position: "QB", teamId: "t-29", teamName: "Washington State" },

  // Group of 5 — Boise State
  { id: "p-73", espnId: 4433089, displayName: "Maddux Madsen", firstName: "Maddux", lastName: "Madsen", jersey: "4", position: "QB", teamId: "t-30", teamName: "Boise State" },
  { id: "p-74", espnId: 4569666, displayName: "Ashton Jeanty", firstName: "Ashton", lastName: "Jeanty", jersey: "2", position: "RB", teamId: "t-30", teamName: "Boise State" },

  // Independents — Notre Dame
  { id: "p-75", espnId: 4433090, displayName: "Riley Leonard", firstName: "Riley", lastName: "Leonard", jersey: "13", position: "QB", teamId: "t-33", teamName: "Notre Dame" },
  { id: "p-76", espnId: 4569777, displayName: "Jeremiyah Love", firstName: "Jeremiyah", lastName: "Love", jersey: "4", position: "RB", teamId: "t-33", teamName: "Notre Dame" },

  // Independents — Army
  { id: "p-77", espnId: 4433091, displayName: "Bryson Daily", firstName: "Bryson", lastName: "Daily", jersey: "13", position: "QB", teamId: "t-34", teamName: "Army" },
];
