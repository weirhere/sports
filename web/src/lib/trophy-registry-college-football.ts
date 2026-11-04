// College football's national champions, 1936–2013, under COR-94's rule: the AP
// poll's final champion through 1997, the BCS National Championship Game's
// winner 1998–2013. 2014 on is the CFP title game, which `deriveTrophies` reads
// off the wire, so it is not repeated here. The web twin of iOS
// `TrophyRegistry+CollegeFootball.swift`, generated from it row for row.
//
// **Sourced 2026-11-04** from Wikipedia's "College football national
// championships in NCAA Division I FBS" (its AP and BCS columns) and checked
// against "AP National Championship Trophy", whose year-by-year list and
// per-school totals table both agree with it on every season. The ids are
// ESPN's, each confirmed against a display name in the captured fixtures.
//
// **2004 has no row.** USC won that season's BCS game and the title was
// vacated; the AP's own 2004 pick (also USC) is not this era's source.

import type { TitleList } from "@/lib/trophy-registry";

// ESPN ids, named so the list below reads against its source.
const alabama = "333";
const army = "349";
const auburn = "2";
const byu = "252";
const clemson = "228";
const colorado = "38";
const florida = "57";
const floridaState = "52";
const georgia = "61";
const lsu = "99";
const maryland = "120";
const miami = "2390";
const michigan = "130";
const michiganState = "127";
const minnesota = "135";
const nebraska = "158";
const notreDame = "87";
const ohioState = "194";
const oklahoma = "201";
const pennState = "213";
const pittsburgh = "221";
const syracuse = "183";
const tcu = "2628";
const tennessee = "2633";
const texas = "251";
const texasAM = "245";
const usc = "30";

export const COLLEGE_FOOTBALL_NATIONAL_TITLES: TitleList = {
  kind: {
    singular: "National Championship",
    plural: "National Championships",
    tier: "league",
  },
  winners: {
    // AP poll
    1936: minnesota, 1937: pittsburgh, 1938: tcu, 1939: texasAM,
    1940: minnesota, 1941: minnesota, 1942: ohioState, 1943: notreDame,
    1944: army, 1945: army, 1946: notreDame, 1947: notreDame,
    1948: michigan, 1949: notreDame, 1950: oklahoma, 1951: tennessee,
    1952: michiganState, 1953: maryland, 1954: ohioState, 1955: oklahoma,
    1956: oklahoma, 1957: auburn, 1958: lsu, 1959: syracuse,
    1960: minnesota, 1961: alabama, 1962: usc, 1963: texas,
    1964: alabama, 1965: alabama, 1966: notreDame, 1967: usc,
    1968: ohioState, 1969: texas, 1970: nebraska, 1971: nebraska,
    1972: usc, 1973: notreDame, 1974: oklahoma, 1975: oklahoma,
    1976: pittsburgh, 1977: notreDame, 1978: alabama, 1979: alabama,
    1980: georgia, 1981: clemson, 1982: pennState, 1983: miami,
    1984: byu, 1985: oklahoma, 1986: pennState, 1987: miami,
    1988: notreDame, 1989: miami, 1990: colorado, 1991: miami,
    1992: alabama, 1993: floridaState, 1994: nebraska, 1995: nebraska,
    1996: florida, 1997: michigan,
    // BCS National Championship Game (2004 vacated)
    1998: tennessee, 1999: floridaState, 2000: oklahoma, 2001: miami,
    2002: ohioState, 2003: lsu, 2005: texas, 2006: florida,
    2007: lsu, 2008: florida, 2009: alabama, 2010: auburn,
    2011: alabama, 2012: alabama, 2013: floridaState,
  },
  verified: true,
  source: "AP poll 1936–97 · title game since 1998",
};
