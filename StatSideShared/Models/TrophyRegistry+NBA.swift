import Foundation

nonisolated extension TrophyRegistry {
    /// The NBA's champions, 1946–47 through 2013–14, keyed by the year each
    /// season opens. 2014–15 on is read off the wire (`TrophyCase.derive`),
    /// so it is not repeated here.
    ///
    /// The three BAA seasons (1946–47 to 1948–49) are in, because the NBA
    /// counts them as its own championships.
    ///
    /// **Titles follow the franchise (COR-94's third call).** A relocated
    /// team's titles stay with it: the Minneapolis Lakers' five go to the
    /// Lakers, the 1951 Rochester Royals' title to the Kings, the 1955
    /// Syracuse Nationals' to the 76ers, the Philadelphia Warriors' two to
    /// Golden State, the 1958 St. Louis Hawks' to Atlanta, the 1978 Bullets'
    /// to the Wizards and the 1979 SuperSonics' to the Thunder, which is
    /// where the NBA files it. **1947–48 has no row:** the original
    /// Baltimore Bullets folded in 1954 and have no successor, and today's
    /// Wizards are a different franchise.
    ///
    /// The ids are ESPN's, each paired with its display name in the captured
    /// `nba-standings` fixture and filed in `Team`'s NBA division map.
    static let nbaChampionships = TitleList(
        // The same kind the wire's "NBA Finals" headline derives, so a
        // registry season and a derived one meet on one row.
        kind: TrophyKind(singular: "NBA Finals", plural: "NBA Finals", tier: .league),
        winners: [
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
        ],
        verified: true
    )

    // ESPN ids, named for today's franchise so the list reads against a
    // champions table that prints the old names.
    private static let bucks = "15"
    private static let bulls = "4"
    private static let celtics = "2"
    private static let hawks = "1"
    private static let heat = "14"
    private static let kings = "23"
    private static let knicks = "18"
    private static let lakers = "13"
    private static let mavericks = "6"
    private static let pistons = "8"
    private static let blazers = "22"
    private static let rockets = "10"
    private static let sixers = "20"
    private static let spurs = "24"
    private static let thunder = "25"
    private static let warriors = "9"
    private static let wizards = "27"
}
