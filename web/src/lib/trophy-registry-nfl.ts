// The NFL's honour rolls before `SEASON_FLOOR`, under COR-94's second and third
// calls. The web twin of iOS `TrophyRegistry+NFL.swift`, generated from it row
// for row.
//
// **NFL Championships, 1920–1965**, as their own kind, so a season never holds
// two titles (the 1966–69 NFL title games fed a Super Bowl and are out). 1920–32
// were decided by the standings; they count because the NFL counts them. Six
// seasons have no row because their champion has no successor team: 1920
// (Akron), 1922–23 (Canton), 1924 (Cleveland Bulldogs), 1926 (Frankford) and
// 1928 (Providence). No AFL title is here.
//
// **Super Bowls I–XLVIII, the 1966–2013 seasons.** 2014 on is read off the wire
// by `deriveTrophies`. Filed by franchise: the Baltimore Colts' titles are
// Indianapolis's, the Raiders' three are Las Vegas's, the Cleveland and St.
// Louis Rams' are Los Angeles's, and the Browns' history stayed in Cleveland.
//
// **Sourced 2026-11-06** from Wikipedia's "List of NFL champions (1920–1969)"
// and "List of Super Bowl champions", season by season.

import type { TitleList } from "@/lib/trophy-registry";

// ESPN ids, named for today's franchise so the lists below read against their
// sources.
const bears = "3";
const broncos = "7";
const browns = "5";
const buccaneers = "27";
const cardinals = "22";
const chiefs = "12";
const colts = "11";
const commanders = "28";
const cowboys = "6";
const dolphins = "15";
const eagles = "21";
const giants = "19";
const jets = "20";
const lions = "8";
const niners = "25";
const packers = "9";
const patriots = "17";
const raiders = "13";
const rams = "14";
const ravens = "33";
const saints = "18";
const seahawks = "26";
const steelers = "23";

export const NFL_CHAMPIONSHIPS: TitleList = {
  kind: {
    singular: "NFL Championship",
    plural: "NFL Championships",
    tier: "league",
  },
  winners: {
    // By the standings (1920, 1922–24, 1926 and 1928 defunct)
    1921: bears, 1925: cardinals, 1927: giants, 1929: packers,
    1930: packers, 1931: packers, 1932: bears,
    // By the NFL Championship Game
    1933: bears, 1934: giants, 1935: lions, 1936: packers,
    1937: commanders, 1938: giants, 1939: packers, 1940: bears,
    1941: bears, 1942: commanders, 1943: bears, 1944: packers,
    1945: rams, 1946: bears, 1947: cardinals, 1948: eagles,
    1949: eagles, 1950: browns, 1951: rams, 1952: lions,
    1953: lions, 1954: browns, 1955: browns, 1956: giants,
    1957: lions, 1958: colts, 1959: colts, 1960: eagles,
    1961: packers, 1962: packers, 1963: bears, 1964: browns,
    1965: packers,
  },
  verified: true,
};

export const SUPER_BOWLS: TitleList = {
  kind: { singular: "Super Bowl", plural: "Super Bowls", tier: "league" },
  winners: {
    1966: packers, 1967: packers, 1968: jets, 1969: chiefs,
    1970: colts, 1971: cowboys, 1972: dolphins, 1973: dolphins,
    1974: steelers, 1975: steelers, 1976: raiders, 1977: cowboys,
    1978: steelers, 1979: steelers, 1980: raiders, 1981: niners,
    1982: commanders, 1983: raiders, 1984: niners, 1985: bears,
    1986: giants, 1987: commanders, 1988: niners, 1989: niners,
    1990: giants, 1991: commanders, 1992: cowboys, 1993: cowboys,
    1994: niners, 1995: cowboys, 1996: packers, 1997: broncos,
    1998: broncos, 1999: rams, 2000: ravens, 2001: patriots,
    2002: buccaneers, 2003: patriots, 2004: patriots, 2005: steelers,
    2006: colts, 2007: giants, 2008: steelers, 2009: saints,
    2010: packers, 2011: giants, 2012: ravens, 2013: seahawks,
  },
  verified: true,
};
