import Foundation

nonisolated extension TrophyRegistry {
    /// The NFL's champions before the Super Bowl, 1920–1965, under COR-94's
    /// second and third calls: their own kind, so a season never holds two
    /// titles (the 1966–69 NFL title games fed a Super Bowl and are out), and
    /// filed under the franchise rather than the name.
    ///
    /// 1920–1932 were decided by the standings, not a game; they count
    /// because the NFL counts them. 1925 is the Chicago Cardinals', as the
    /// league records it. No AFL title is here.
    ///
    /// **Six seasons have no row**, because their champion has no successor
    /// team: 1920 (Akron Pros), 1922 and 1923 (Canton Bulldogs), 1924
    /// (Cleveland Bulldogs), 1926 (Frankford Yellow Jackets — the Eagles are
    /// a 1933 franchise of their own) and 1928 (Providence Steam Roller).
    ///
    /// **Sourced 2026-11-06** from Wikipedia's "List of NFL champions
    /// (1920–1969)", season by season, and checked against that page's
    /// by-franchise table — which counts to 1969, so its Packers 11 and
    /// Baltimore Colts 3 come to 9 and 2 once 1966–69 are cut.
    static let nflChampionships = TitleList(
        kind: TrophyKind(singular: "NFL Championship",
                         plural: "NFL Championships", tier: .league),
        winners: [
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
        ],
        verified: true
    )

    /// Super Bowl winners for the 1966–2013 seasons, Super Bowls I–XLVIII.
    /// 2014 on is read off the wire by `TrophyCase.derive`, so it is not
    /// repeated here. No `source`: a Super Bowl is its own.
    ///
    /// Filed by franchise: the Baltimore Colts' 1970 title is Indianapolis's,
    /// the Oakland and Los Angeles Raiders' three are Las Vegas's, the St.
    /// Louis Rams' 1999 is Los Angeles's, and Washington's three are the
    /// Commanders'. The Ravens' 2000 and 2012 are their own — the Browns'
    /// history stayed in Cleveland.
    ///
    /// **Sourced 2026-11-06** from Wikipedia's "List of Super Bowl
    /// champions", game by game through XLVIII. The per-franchise totals the
    /// tests hold were counted from that list independently of these rows.
    static let superBowls = TitleList(
        kind: TrophyKind(singular: "Super Bowl", plural: "Super Bowls", tier: .league),
        winners: [
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
        ],
        verified: true
    )

    // ESPN ids, named for today's franchise so the lists above read against
    // their sources. Each is the id ESPN's `nfl/teams` pairs with that
    // team's abbreviation (captured as the `nfl-teams` fixture).
    private static let bears = "3"
    private static let broncos = "7"
    private static let browns = "5"
    private static let buccaneers = "27"
    private static let cardinals = "22"
    private static let chiefs = "12"
    private static let colts = "11"
    private static let commanders = "28"
    private static let cowboys = "6"
    private static let dolphins = "15"
    private static let eagles = "21"
    private static let giants = "19"
    private static let jets = "20"
    private static let lions = "8"
    private static let niners = "25"
    private static let packers = "9"
    private static let patriots = "17"
    private static let raiders = "13"
    private static let rams = "14"
    private static let ravens = "33"
    private static let saints = "18"
    private static let seahawks = "26"
    private static let steelers = "23"
}
