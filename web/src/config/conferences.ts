import type { Conference } from "@/lib/types";

export const FBS_CONFERENCES: Conference[] = [
  {
    id: "1",
    name: "Atlantic Coast Conference",
    shortName: "ACC",
    division: "FBS",
  },
  { id: "4", name: "Big 12 Conference", shortName: "Big 12", division: "FBS" },
  { id: "5", name: "Big Ten Conference", shortName: "Big Ten", division: "FBS" },
  {
    id: "8",
    name: "Southeastern Conference",
    shortName: "SEC",
    division: "FBS",
  },
  // Group of 5
  {
    id: "151",
    name: "American Athletic Conference",
    shortName: "AAC",
    division: "FBS",
  },
  {
    id: "12",
    name: "Conference USA",
    shortName: "C-USA",
    division: "FBS",
  },
  {
    id: "15",
    name: "Mid-American Conference",
    shortName: "MAC",
    division: "FBS",
  },
  {
    id: "17",
    name: "Mountain West Conference",
    shortName: "MWC",
    division: "FBS",
  },
  {
    id: "37",
    name: "Sun Belt Conference",
    shortName: "Sun Belt",
    division: "FBS",
  },
  {
    id: "9",
    name: "Pac-12 Conference",
    shortName: "Pac-12",
    division: "FBS",
  },
  {
    id: "18",
    name: "FBS Independents",
    shortName: "Ind.",
    division: "FBS",
  },
];

export function getConferenceById(id: string): Conference | undefined {
  return FBS_CONFERENCES.find((c) => c.id === id);
}
