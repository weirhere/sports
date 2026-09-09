import { describe, it, expect } from "vitest";
import {
  apiBase,
  canTableAWholeSeason,
  espnSeason,
  hasPoll,
  hasWeeks,
  leagueLogoUrl,
  parseLeague,
  playsOnASurface,
  seasonLabel,
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

  it("refuses a whole-season fetch for a league ESPN truncates", () => {
    // A season-long NBA window returns exactly 900 events and 12 MB,
    // silently truncating in February — and `groups=` is ignored outside
    // football, so there is no narrow fetch to fall back on.
    expect(canTableAWholeSeason("cfb")).toBe(true);
    expect(canTableAWholeSeason("nba")).toBe(false);
    expect(canTableAWholeSeason("nhl")).toBe(false);
  });

  it("only calls a surface a fact where the game is played on one", () => {
    // ESPN ships `grass: false` for arenas too, which rendered as
    // "Surface · Turf" on a hockey rink.
    expect(playsOnASurface("cfb")).toBe(true);
    expect(playsOnASurface("nhl")).toBe(false);
  });
});
