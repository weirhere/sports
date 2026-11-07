import Foundation

nonisolated extension TrophyRegistry {
    /// Stanley Cup winners for the NHL's seasons 1917–18 through 2013–14,
    /// keyed by the year each season opens (1917 is the 1918 Cup). 2014–15 on
    /// is read off the wire by `TrophyCase.derive`, so it is not repeated
    /// here. No `source`: a Stanley Cup is won on the ice.
    ///
    /// The span is COR-94's: the Cup from the NHL's first season, so the
    /// Canadiens' 1916 Cup (an NHA title) is not here and Montreal reads 23
    /// before the wire adds any.
    ///
    /// Under the third call, titles follow the franchise: the Toronto
    /// Arenas' 1918 and St. Patricks' 1922 Cups are the Maple Leafs', and the
    /// Black Hawks' are the Blackhawks'. **Seven seasons have no row**
    /// because their winner has no successor team: the original Ottawa
    /// Senators' 1920, 1921, 1923 and 1927 Cups (today's Senators are a 1992
    /// franchise of their own), the Montreal Maroons' 1926 and 1935, and the
    /// WCHL's Victoria Cougars in 1925. **Two more have none** because no Cup
    /// was awarded: 1918–19 (the final was abandoned in the flu epidemic) and
    /// 2004–05 (the lockout).
    ///
    /// **Sourced 2026-11-06** from Wikipedia's "List of Stanley Cup
    /// champions", season by season. The per-franchise totals the tests hold
    /// were counted from that list independently of these rows.
    static let stanleyCups = TitleList(
        kind: TrophyKind(singular: "Stanley Cup", plural: "Stanley Cups", tier: .league),
        winners: [
            // 1918 no Cup; 1919, 1920, 1922 and 1926 Ottawa; 1924 Victoria;
            // 1925 Maroons
            1917: mapleLeafs, 1921: mapleLeafs, 1923: canadiens,
            1927: rangers, 1928: bruins, 1929: canadiens,
            1930: canadiens, 1931: mapleLeafs, 1932: rangers, 1933: blackhawks,
            // 1934 Maroons
            1935: redWings, 1936: redWings, 1937: blackhawks, 1938: bruins,
            1939: rangers,
            1940: bruins, 1941: redWings, 1942: mapleLeafs, 1943: canadiens,
            1944: mapleLeafs, 1945: canadiens, 1946: mapleLeafs, 1947: mapleLeafs,
            1948: mapleLeafs, 1949: redWings,
            1950: mapleLeafs, 1951: redWings, 1952: canadiens, 1953: redWings,
            1954: redWings, 1955: canadiens, 1956: canadiens, 1957: canadiens,
            1958: canadiens, 1959: canadiens,
            1960: blackhawks, 1961: mapleLeafs, 1962: mapleLeafs, 1963: mapleLeafs,
            1964: canadiens, 1965: canadiens, 1966: mapleLeafs, 1967: canadiens,
            1968: canadiens, 1969: bruins,
            1970: canadiens, 1971: bruins, 1972: canadiens, 1973: flyers,
            1974: flyers, 1975: canadiens, 1976: canadiens, 1977: canadiens,
            1978: canadiens, 1979: islanders,
            1980: islanders, 1981: islanders, 1982: islanders, 1983: oilers,
            1984: oilers, 1985: canadiens, 1986: oilers, 1987: oilers,
            1988: flames, 1989: oilers,
            1990: penguins, 1991: penguins, 1992: canadiens, 1993: rangers,
            1994: devils, 1995: avalanche, 1996: redWings, 1997: redWings,
            1998: stars, 1999: devils,
            2000: avalanche, 2001: redWings, 2002: devils, 2003: lightning,
            // 2004 lockout
            2005: hurricanes, 2006: ducks, 2007: redWings, 2008: penguins,
            2009: blackhawks,
            2010: bruins, 2011: kings, 2012: blackhawks, 2013: kings,
        ],
        verified: true
    )

    // ESPN ids, named for today's franchise so the list above reads against
    // its source. Each is the id ESPN's NHL standings pair with that team's
    // abbreviation (captured as the `nhl-standings` fixture).
    private static let avalanche = "17"
    private static let blackhawks = "4"
    private static let bruins = "1"
    private static let canadiens = "10"
    private static let devils = "11"
    private static let ducks = "25"
    private static let flames = "3"
    private static let flyers = "15"
    private static let hurricanes = "7"
    private static let islanders = "12"
    private static let kings = "8"
    private static let lightning = "20"
    private static let mapleLeafs = "21"
    private static let oilers = "6"
    private static let penguins = "16"
    private static let rangers = "13"
    private static let redWings = "5"
    private static let stars = "9"
}
