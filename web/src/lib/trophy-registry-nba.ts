// The NBA's champions, 1946–47 through 2013–14, keyed by the year each season
// opens. 2014–15 on is read off the wire (`deriveTrophies`), so it is not
// repeated here. The web twin of iOS `TrophyRegistry+NBA.swift`, generated
// from it row for row.
//
// The three BAA seasons (1946–47 to 1948–49) are in, because the NBA counts
// them as its own championships.
//
// **Titles follow the franchise (COR-94's third call).** A relocated team's
// titles stay with it: Minneapolis to the Lakers, Rochester to the Kings,
// Syracuse to the 76ers, Philadelphia to the Warriors, St. Louis to the Hawks,
// the 1978 Bullets to the Wizards and the 1979 SuperSonics to the Thunder.
// **1947–48 has no row:** the original Baltimore Bullets folded in 1954 with no
// successor.

import type { TitleList } from "@/lib/trophy-registry";

// ESPN ids, named for today's franchise.
const blazers = "22";
const bucks = "15";
const bulls = "4";
const celtics = "2";
const hawks = "1";
const heat = "14";
const kings = "23";
const knicks = "18";
const lakers = "13";
const mavericks = "6";
const pistons = "8";
const rockets = "10";
const sixers = "20";
const spurs = "24";
const thunder = "25";
const warriors = "9";
const wizards = "27";

export const NBA_CHAMPIONSHIPS: TitleList = {
  kind: { singular: "NBA Finals", plural: "NBA Finals", tier: "league" },
  winners: {
    // BAA (1947 has no row: the original Baltimore Bullets)
    1946: warriors, 1948: lakers,
    // NBA
    1949: lakers, 1950: kings, 1951: lakers, 1952: lakers,
    1953: lakers, 1954: sixers, 1955: warriors, 1956: celtics,
    1957: hawks, 1958: celtics, 1959: celtics, 1960: celtics,
    1961: celtics, 1962: celtics, 1963: celtics, 1964: celtics,
    1965: celtics, 1966: sixers, 1967: celtics, 1968: celtics,
    1969: knicks, 1970: bucks, 1971: lakers, 1972: knicks,
    1973: celtics, 1974: warriors, 1975: celtics, 1976: blazers,
    1977: wizards, 1978: thunder, 1979: lakers, 1980: celtics,
    1981: lakers, 1982: sixers, 1983: celtics, 1984: lakers,
    1985: celtics, 1986: lakers, 1987: lakers, 1988: pistons,
    1989: pistons, 1990: bulls, 1991: bulls, 1992: bulls,
    1993: rockets, 1994: rockets, 1995: bulls, 1996: bulls,
    1997: bulls, 1998: spurs, 1999: lakers, 2000: lakers,
    2001: lakers, 2002: spurs, 2003: pistons, 2004: spurs,
    2005: heat, 2006: spurs, 2007: celtics, 2008: lakers,
    2009: lakers, 2010: mavericks, 2011: heat, 2012: heat,
    2013: spurs,
    
  },
  verified: true,
};
