// The athlete payloads → domain. Fixtures are trimmed from live
// `site.web.api` responses (2026-09-25): an NBA forward traded twice, and a
// college receiver whose log has one scored game.

import { describe, expect, it } from "vitest";
import {
  athleteGameLogUrl,
  athleteStatsUrl,
  athleteUrl,
  transformAthleteGameLog,
  transformAthleteProfile,
  transformAthleteStats,
  type EspnAthleteGameLogResponse,
  type EspnAthleteResponse,
  type EspnAthleteStatsResponse,
} from "./athlete";

describe("the URLs", () => {
  it("read site.web.api's common/v3 tree, not site.api", () => {
    expect(athleteUrl("nba", "1966")).toBe(
      "https://site.web.api.espn.com/apis/common/v3/sports/basketball/nba/athletes/1966"
    );
    expect(athleteStatsUrl("cfb", "5078453")).toBe(
      "https://site.web.api.espn.com/apis/common/v3/sports/football/college-football/athletes/5078453/stats"
    );
    expect(athleteGameLogUrl("nhl", "3895074", 2026)).toBe(
      "https://site.web.api.espn.com/apis/common/v3/sports/hockey/nhl/athletes/3895074/gamelog?season=2026"
    );
    expect(athleteGameLogUrl("nfl", "1")).not.toContain("season=");
  });
});

describe("the athlete profile", () => {
  const payload: EspnAthleteResponse = {
    athlete: {
      displayName: "LeBron James",
      age: 41,
      jersey: "23",
      displayHeight: "6' 9\"",
      displayWeight: "250 lbs",
      position: { abbreviation: "F", displayName: "Forward" },
      headshot: { href: "https://a.espncdn.com/i/headshots/nba/players/full/1966.png" },
      status: { name: "Active", type: "active" },
      team: {
        id: "20",
        displayName: "Philadelphia 76ers",
        location: "Philadelphia",
        logos: [
          { href: "https://a.espncdn.com/i/teamlogos/nba/500-dark/phi.png", rel: ["full", "dark"] },
          { href: "https://a.espncdn.com/i/teamlogos/nba/500/phi.png", rel: ["full", "default"] },
        ],
      },
    },
  };

  it("maps every fact, and names the team off the payload", () => {
    expect(transformAthleteProfile(payload)).toEqual({
      name: "LeBron James",
      age: 41,
      jersey: "23",
      position: "F",
      positionName: "Forward",
      height: "6' 9\"",
      weight: "250 lbs",
      headshotUrl: "https://a.espncdn.com/i/headshots/nba/players/full/1966.png",
      injuryStatus: undefined,
      teamId: "20",
      teamName: "Philadelphia 76ers",
      teamLogoUrl: "https://a.espncdn.com/i/teamlogos/nba/500/phi.png",
    });
  });

  it("keeps a real injury status and drops ESPN's blanket Active", () => {
    const hurt = transformAthleteProfile({
      athlete: { ...payload.athlete, status: { name: "Day-To-Day", type: "day-to-day" } },
    });
    expect(hurt?.injuryStatus).toBe("Day-To-Day");
  });

  it("falls back to the location, and takes a numeric team id", () => {
    const profile = transformAthleteProfile({
      athlete: { displayName: "X", team: { id: 61, location: "Georgia" } },
    });
    expect(profile?.teamId).toBe("61");
    expect(profile?.teamName).toBe("Georgia");
    expect(profile?.teamLogoUrl).toBeUndefined();
  });

  it("is undefined with no athlete, and sparse rather than broken with a bare one", () => {
    expect(transformAthleteProfile({})).toBeUndefined();
    const bare = transformAthleteProfile({ athlete: {} });
    expect(bare?.name).toBeUndefined();
    expect(bare?.teamId).toBeUndefined();
  });
});

describe("the stats", () => {
  const payload: EspnAthleteStatsResponse = {
    teams: {
      "cleveland-cavaliers": { id: "5", displayName: "Cleveland Cavaliers", abbreviation: "CLE" },
      "los-angeles-lakers": { id: 13, displayName: "Los Angeles Lakers", abbreviation: "LAL" },
    },
    categories: [
      {
        name: "averages",
        displayName: "Regular Season Averages",
        labels: ["GP", "REB", "AST", "PTS"],
        names: ["gamesPlayed", "avgRebounds", "avgAssists", "avgPoints"],
        displayNames: ["Games Played", "Rebounds Per Game", "Assists Per Game", "Points Per Game"],
        statistics: [
          { teamId: "5", season: { year: 2004, displayName: "2003-04" }, stats: ["79", "5.5", "5.9", "20.9"], position: "F" },
          // Wrong width: dropped rather than shifting every number a column.
          { teamId: "5", season: { year: 2005, displayName: "2004-05" }, stats: ["80", "7.4"] },
          { teamId: "13", season: { year: 2026, displayName: "2025-26" }, stats: ["60", "6.1", "7.2", "20.9"] },
        ],
        totals: ["1622", "7.5", "7.4", "26.8"],
      },
      // No rows that survive: the whole category goes.
      { name: "empty", labels: ["A"], statistics: [] },
      // No name: nothing to key the headline registry on.
      { labels: ["A"], statistics: [{ season: { year: 2026 }, stats: ["1"] }] },
    ],
  };

  it("keeps ESPN's rows, clubs and career line", () => {
    const stats = transformAthleteStats(payload);
    expect(stats.categories).toHaveLength(1);
    const [averages] = stats.categories;
    expect(averages.id).toBe("averages");
    expect(averages.title).toBe("Regular Season Averages");
    expect(averages.seasons.map((line) => line.label)).toEqual(["2003-04", "2025-26"]);
    expect(averages.seasons[1]).toMatchObject({
      year: 2026,
      teamId: "13",
      teamName: "Los Angeles Lakers",
      teamAbbreviation: "LAL",
    });
    expect(averages.career).toEqual(["1622", "7.5", "7.4", "26.8"]);
  });

  it("drops a career line that doesn't match the header", () => {
    const stats = transformAthleteStats({
      categories: [{ ...payload.categories![0], totals: ["1"] }],
    });
    expect(stats.categories[0].career).toEqual([]);
  });

  it("labels a season by its year when ESPN sends no display name", () => {
    const stats = transformAthleteStats({
      categories: [{ name: "passing", labels: ["YDS"], statistics: [{ season: { year: 2026 }, stats: ["10"] }] }],
    });
    expect(stats.categories[0].seasons[0].label).toBe("2026");
    expect(stats.categories[0].title).toBe("passing");
  });

  it("is empty for an empty payload", () => {
    expect(transformAthleteStats({})).toEqual({ categories: [] });
  });
});

describe("the game log", () => {
  const payload: EspnAthleteGameLogResponse = {
    labels: ["REC", "YDS", "TD"],
    names: ["receptions", "receivingYards", "receivingTouchdowns"],
    filters: [
      { name: "league", value: "college-football" },
      { name: "season", value: "2026", options: [{ value: "2026" }, { value: "2025" }, { value: "x" }] },
    ],
    events: {
      "401856673": {
        week: 2,
        atVs: "vs",
        gameDate: "2026-09-12T16:45:00.000+00:00",
        homeTeamScore: "70",
        awayTeamScore: "20",
        gameResult: "W",
        opponent: { id: "98", abbreviation: "WKU", displayName: "Western Kentucky Hilltoppers", logo: "https://a.espncdn.com/i/teamlogos/ncaa/500/98.png" },
        team: { id: "61", abbreviation: "UGA", displayName: null },
      },
      "401856686": {
        week: 3,
        atVs: "@",
        homeTeamScore: "17",
        awayTeamScore: "45",
        gameResult: "W",
        opponent: { id: 8, abbreviation: "ARK" },
      },
    },
    seasonTypes: [
      {
        displayName: "2026 Regular Season",
        categories: [
          {
            type: "event",
            events: [
              { eventId: "401856686", stats: ["3", "40", "0"] },
              { eventId: "401856673", stats: ["2", "11", "1"] },
              // Wrong width — never shifted under the wrong column.
              { eventId: "999", stats: ["1"] },
            ],
          },
          // ESPN's own subtotal row is not a game.
          { type: "total", events: [{ eventId: "total", stats: ["5", "51", "1"] }] },
        ],
      },
      // A season type with nothing in it is no section at all.
      { displayName: "2026 Postseason", categories: [] },
    ],
  };

  it("reads sections, seasons and the scores from the player's side", () => {
    const log = transformAthleteGameLog(payload);
    expect(log.season).toBe(2026);
    expect(log.availableSeasons).toEqual([2026, 2025]);
    expect(log.sections).toHaveLength(1);
    expect(log.sections[0].title).toBe("2026 Regular Season");
    const [away, home] = log.sections[0].entries;
    expect(away).toMatchObject({
      eventId: "401856686",
      isAway: true,
      week: 3,
      opponentId: "8",
      teamScore: "45",
      opponentScore: "17",
      result: "W",
    });
    expect(home).toMatchObject({
      eventId: "401856673",
      isAway: false,
      teamId: "61",
      teamScore: "70",
      opponentScore: "20",
      opponentName: "Western Kentucky Hilltoppers",
    });
  });

  it("keeps a row whose event ESPN didn't describe, with what it has", () => {
    const log = transformAthleteGameLog({
      labels: ["PTS"],
      seasonTypes: [{ categories: [{ events: [{ eventId: "1", stats: ["30"] }] }] }],
    });
    expect(log.sections[0].title).toBe("Games");
    expect(log.sections[0].entries[0]).toMatchObject({ eventId: "1", isAway: false, values: ["30"] });
    expect(log.season).toBeUndefined();
  });

  it("is empty for an empty payload", () => {
    expect(transformAthleteGameLog({})).toEqual({
      labels: [],
      names: [],
      sections: [],
      availableSeasons: [],
      season: undefined,
    });
  });
});
