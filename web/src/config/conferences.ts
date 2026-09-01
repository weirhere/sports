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

export const FCS_CONFERENCES: Conference[] = [
  { id: "20", name: "Big Sky Conference", shortName: "Big Sky", division: "FCS" },
  { id: "40", name: "Big South-OVC", shortName: "Big South-OVC", division: "FCS" },
  { id: "48", name: "CAA Football", shortName: "CAA", division: "FCS" },
  { id: "21", name: "Ivy League", shortName: "Ivy", division: "FCS" },
  { id: "24", name: "MEAC", shortName: "MEAC", division: "FCS" },
  { id: "22", name: "Missouri Valley Football", shortName: "MVFC", division: "FCS" },
  { id: "25", name: "Northeast Conference", shortName: "NEC", division: "FCS" },
  { id: "26", name: "Patriot League", shortName: "Patriot", division: "FCS" },
  { id: "27", name: "Pioneer Football League", shortName: "Pioneer", division: "FCS" },
  { id: "28", name: "Southern Conference", shortName: "SoCon", division: "FCS" },
  { id: "29", name: "Southland Conference", shortName: "Southland", division: "FCS" },
  { id: "31", name: "SWAC", shortName: "SWAC", division: "FCS" },
  { id: "43", name: "United Athletic Conference", shortName: "UAC", division: "FCS" },
  { id: "176", name: "FCS Independents", shortName: "Ind.", division: "FCS" },
];

export const ALL_CONFERENCES = [...FBS_CONFERENCES, ...FCS_CONFERENCES];

export function getConferenceById(id: string): Conference | undefined {
  return ALL_CONFERENCES.find((c) => c.id === id);
}
