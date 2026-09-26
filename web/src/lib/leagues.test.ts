import { describe, it, expect } from "vitest";
import {
  apiBase,
  belongsToSeason,
  espnSeason,
  hasPoll,
  hasWeeks,
  LEAGUE_DISPLAY_ORDER,
  LEAGUES,
  leagueLogoUrl,
  parseLeague,
  playsOnASurface,
  seasonLabel,
  seasonGamesSpan,
  seasonSpan,
  seasonYear,
  seasonYearContaining,
  seasonYearFromEspn,
  slateSplitsByConference,
  unionSeasonSpan,
} from "./leagues";

describe("league identity", () => {
  it("builds each league's base URL from its sport and league segments", () => {
    // The three bases were spelled `/football/` as a literal before the
    // axis existed — basketball and hockey don't share football's segment.
    expect(apiBase("cfb")).toContain("/football/college-football");
    expect(apiBase("nfl")).toContain("/football/nfl");
    expect(apiBase("nba")).toContain("/basketball/nba");
    expect(apiBase("nhl")).toContain("/hockey/nhl");
  });

  it("parses a league token and rejects anything else", () => {
    expect(parseLeague("nfl")).toBe("nfl");
    expect(parseLeague("mls")).toBeUndefined();
    expect(parseLeague(null)).toBeUndefined();
  });

  it("files college football's mark under redesign/, not leagues/", () => {
    // `leagues/500/college-football.png` 404s, along with every other
    // plausible spelling in that bucket; ESPN ships this one on every NCAAF
    // scoreboard response.
    expect(leagueLogoUrl("cfb")).toContain("/redesign/");
    expect(leagueLogoUrl("nfl")).toBe(
      "https://a.espncdn.com/i/teamlogos/leagues/500/nfl.png"
    );
  });
});

describe("season-year translation", () => {
  it("leaves football's seasons alone", () => {
    // Football names a season by the year it opens.
    expect(espnSeason("cfb", 2026)).toBe(2026);
    expect(espnSeason("nfl", 2026)).toBe(2026);
  });

  it("shifts the NBA and NHL to the year their season ends", () => {
    // `season=2027` is October 2026 → June 2027, displayName "2026-27".
    // Our own axis is always the opening year; this is the one boundary
    // where it is translated.
    expect(espnSeason("nba", 2026)).toBe(2027);
    expect(espnSeason("nhl", 2026)).toBe(2027);
  });

  it("round-trips a payload's season back onto our axis", () => {
    for (const league of ["cfb", "nfl", "nba", "nhl"] as const) {
      expect(seasonYearFromEspn(league, espnSeason(league, 2019))).toBe(2019);
    }
  });

  it("labels a season the way ESPN's own displayName does", () => {
    expect(seasonLabel("cfb", 2026)).toBe("2026");
    expect(seasonLabel("nba", 2026)).toBe("2026-27");
  });

  it("pads the two-digit half at a decade boundary", () => {
    // 2009 is "2009-10", never "2009-1".
    expect(seasonLabel("nhl", 2009)).toBe("2009-10");
    expect(seasonLabel("nhl", 1999)).toBe("1999-00");
  });
});

describe("which season a date belongs to", () => {
  it("puts January in college football's previous season", () => {
    // Bowls and the CFP run into January.
    expect(seasonYear("cfb", new Date(2027, 0, 10))).toBe(2026);
    expect(seasonYear("cfb", new Date(2026, 8, 5))).toBe(2026);
  });

  it("puts February in the NFL's previous season", () => {
    // The Super Bowl is in February.
    expect(seasonYear("nfl", new Date(2027, 1, 7))).toBe(2026);
    expect(seasonYear("nfl", new Date(2027, 2, 1))).toBe(2027);
  });

  it("reads a hockey page's June on hockey's clock", () => {
    // A college-football rollover would call June "next season" while the
    // Cup was still being played for.
    expect(seasonYear("nhl", new Date(2027, 5, 15))).toBe(2026);
    expect(seasonYear("cfb", new Date(2027, 5, 15))).toBe(2027);
  });
});

describe("season games spans", () => {
  it("is the day strip's span for every ordinary season", () => {
    for (const league of ["cfb", "nfl", "nba", "nhl"] as const) {
      for (const year of [2014, 2018, 2021, 2025]) {
        expect(seasonGamesSpan(league, year)).toEqual(seasonSpan(league, year));
      }
    }
  });

  it("runs the 2019-20 bubbles into the autumn", () => {
    // The NBA Finals ended 2020-10-11, the Stanley Cup 2020-09-28.
    expect(seasonGamesSpan("nba", 2019)).toEqual({
      start: new Date(2019, 8, 1),
      end: new Date(2020, 9, 31),
    });
    expect(seasonGamesSpan("nhl", 2019).end).toEqual(new Date(2020, 8, 30));
  });

  it("runs the late-starting 2020-21 seasons into July", () => {
    // NBA Finals 2021-07-20, Stanley Cup 2021-07-07.
    expect(seasonGamesSpan("nba", 2020).end).toEqual(new Date(2021, 6, 31));
    expect(seasonGamesSpan("nhl", 2020).end).toEqual(new Date(2021, 6, 31));
  });

  it("never moves football's seasons", () => {
    expect(seasonGamesSpan("cfb", 2020)).toEqual(seasonSpan("cfb", 2020));
    expect(seasonGamesSpan("nfl", 2019)).toEqual(seasonSpan("nfl", 2019));
  });
});

describe("season membership", () => {
  it("reads an end-year league's stamp onto the start-year axis", () => {
    // ESPN stamps the 2025-26 NBA season 2026.
    expect(belongsToSeason("nba", 2025, 2026)).toBe(true);
    expect(belongsToSeason("nba", 2025, 2025)).toBe(false);
    expect(belongsToSeason("cfb", 2025, 2025)).toBe(true);
  });

  it("keeps the bubble out of the season whose span overlaps it", () => {
    // September 2020 is inside 2020-21's span and full of 2019-20's
    // playoffs, which ESPN stamps 2020 — our 2019.
    expect(belongsToSeason("nhl", 2020, 2020)).toBe(false);
    expect(belongsToSeason("nhl", 2019, 2020)).toBe(true);
  });

  it("keeps an event with no stamp", () => {
    expect(belongsToSeason("nba", 2025, undefined)).toBe(true);
  });
});

describe("season spans", () => {
  it("opens the NFL's season in July for the Hall of Fame Game", () => {
    // An August floor cut the front off the season entirely.
    const span = seasonSpan("nfl", 2026);
    expect(span.start.getMonth()).toBe(6);
    expect(span.end.getMonth()).toBe(1); // February
  });

  it("runs college football August through January", () => {
    const span = seasonSpan("cfb", 2026);
    expect(span.start.getMonth()).toBe(7);
    expect(span.end.getMonth()).toBe(0);
  });

  it("runs basketball and hockey September through June, by the start year", () => {
    // Our 2025 is ESPN's 2026: the NHL's preseason opened 2025-09-20 and
    // both finals were decided by 2026-06-15 (probed live 2026-09-25).
    for (const league of ["nba", "nhl"] as const) {
      const span = seasonSpan(league, 2025);
      expect(span.start).toEqual(new Date(2025, 8, 1));
      expect(span.end).toEqual(new Date(2026, 5, 30));
    }
  });

  it("leaves the app no offseason — July through June", () => {
    // College football's August used to open the app's season and the
    // NFL's February closed it. The NBA and NHL run into June.
    const span = unionSeasonSpan(2026);
    expect(span.start.getMonth()).toBe(6); // July, the NFL's
    expect(span.end.getMonth()).toBe(5); // June, the NBA's and NHL's
  });

  it("resolves every month to the season it belongs to", () => {
    // The union rolls over after the latest league's month, so a spring day
    // belongs to the season that opened the previous summer.
    expect(seasonYearContaining(new Date(2027, 3, 15))).toBe(2026);
    expect(seasonYearContaining(new Date(2026, 8, 5))).toBe(2026);
    expect(seasonYearContaining(new Date(2027, 6, 1))).toBe(2027);
  });
});

describe("behavioral gates", () => {
  it("splits only college football's slate by conference", () => {
    // 60 rows on a Saturday need carving; a 16-game NFL Sunday, an 11-game
    // NBA night and an 8-game NHL night are each the whole slate at a
    // glance.
    expect(slateSplitsByConference("cfb")).toBe(true);
    expect(slateSplitsByConference("nfl")).toBe(false);
    expect(slateSplitsByConference("nba")).toBe(false);
  });

  it("gives weeks only to the leagues that have them", () => {
    // ESPN sends `week: null` on every NBA and NHL event.
    expect(hasWeeks("cfb")).toBe(true);
    expect(hasWeeks("nfl")).toBe(true);
    expect(hasWeeks("nba")).toBe(false);
    expect(hasWeeks("nhl")).toBe(false);
  });

  it("polls college football alone", () => {
    expect(hasPoll("cfb")).toBe(true);
    expect(hasPoll("nfl")).toBe(false);
  });

  it("only calls a surface a fact where the game is played on one", () => {
    // ESPN ships `grass: false` for arenas too, which rendered as
    // "Surface · Turf" on a hockey rink.
    expect(playsOnASurface("cfb")).toBe(true);
    expect(playsOnASurface("nhl")).toBe(false);
  });
});

describe("display order", () => {
  it("lists leagues A–Z by the name on screen", () => {
    expect(LEAGUE_DISPLAY_ORDER).toEqual(["nba", "cfb", "nfl", "nhl"]);
  });

  it("leaves the declaration order alone for fetches and spans", () => {
    expect(LEAGUES).toEqual(["cfb", "nfl", "nba", "nhl"]);
  });
});
