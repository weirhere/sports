import { describe, expect, it } from "vitest";
import type { Game, GameStatus, GameTeam, Team } from "./types";
import type { League } from "./leagues";
import {
  foldSlate,
  gamesForTeam,
  isGameSpent,
  preseasonTitle,
  slateDayTitle,
  slateGroups,
  slateWeekId,
} from "./conference-slate";

function team(id: string, school: string, league: League = "cfb"): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name: school,
    school,
    abbreviation: school.slice(0, 3).toUpperCase(),
    conferenceId: "8",
    conferenceName: "",
    logoUrl: "",
  };
}

function side(t: Team): GameTeam {
  return { team: t, score: null };
}

const georgia = team("61", "Georgia");
const alabama = team("333", "Alabama");
const bills = team("2", "Buffalo", "nfl");
const chiefs = team("12", "Kansas City", "nfl");

let nextId = 1;
function game(fields: {
  scheduledAt?: string;
  week?: number;
  seasonType?: number;
  status?: GameStatus;
  home?: Team;
  away?: Team;
}): Game {
  const home = fields.home ?? georgia;
  return {
    id: `g${nextId++}`,
    league: home.league,
    status: fields.status ?? "scheduled",
    scheduledAt: fields.scheduledAt ?? "2026-09-05T19:30:00Z",
    venue: { name: "", city: "", state: "" },
    homeTeam: side(home),
    awayTeam: side(fields.away ?? alabama),
    seasonYear: 2026,
    conferenceGame: false,
    week: fields.week,
    seasonType: fields.seasonType,
  };
}

/** A local-midday instant, so a fixture can never drift into the day either
 *  side of the one it means whatever zone the test runs in. */
function at(year: number, month: number, day: number, hour = 12): string {
  return new Date(year, month - 1, day, hour).toISOString();
}

describe("week grouping", () => {
  it("orders weeks ascending and trails the postseason despite its week 1", () => {
    const groups = slateGroups(
      [
        game({ week: 1, seasonType: 3, scheduledAt: at(2027, 1, 8) }),
        game({ week: 2, scheduledAt: at(2026, 9, 12) }),
        game({ week: 1, scheduledAt: at(2026, 9, 5) }),
      ],
      "week"
    );
    expect(groups.map((g) => g.title)).toEqual(["Week 1", "Week 2", "Postseason"]);
  });

  it("leads with the preseason, which never shares the regular season's weeks", () => {
    const groups = slateGroups(
      [
        game({ week: 1, scheduledAt: at(2026, 9, 10), home: bills, away: chiefs }),
        game({
          week: 1,
          seasonType: 1,
          scheduledAt: at(2026, 7, 30),
          home: bills,
          away: chiefs,
        }),
      ],
      "week"
    );
    expect(groups.map((g) => g.title)).toEqual(["Hall of Fame Game", "Week 1"]);
  });

  it("names preseason cards the way fans count them", () => {
    expect(preseasonTitle(1, "nfl")).toBe("Hall of Fame Game");
    expect(preseasonTitle(2, "nfl")).toBe("Preseason Week 1");
    expect(preseasonTitle(4, "nfl")).toBe("Preseason Week 3");
  });

  it("leaves another league's preseason its own numbers", () => {
    expect(preseasonTitle(1, "cfb")).toBe("Preseason Week 1");
    expect(preseasonTitle(undefined, "nfl")).toBe("Preseason");
  });

  it("gives every preseason card the id its week names", () => {
    expect(slateWeekId(game({ week: 2, seasonType: 1 }))).toBe("preseason-2");
    expect(slateWeekId(game({ seasonType: 1 }))).toBe("preseason-other");
    expect(slateWeekId(game({ week: 1, seasonType: 3 }))).toBe("week-postseason");
    expect(slateWeekId(game({ week: 4 }))).toBe("week-4");
    expect(slateWeekId(game({}))).toBe("week-other");
  });

  it("buckets weekless games before the postseason", () => {
    const groups = slateGroups(
      [
        game({ week: 1, seasonType: 3, scheduledAt: at(2027, 1, 8) }),
        game({ scheduledAt: at(2026, 12, 1) }),
        game({ week: 1, scheduledAt: at(2026, 9, 5) }),
      ],
      "week"
    );
    expect(groups.map((g) => g.title)).toEqual([
      "Week 1",
      "More games",
      "Postseason",
    ]);
  });
});

describe("day grouping", () => {
  it("ignores the season type entirely — one card per day, in order", () => {
    const groups = slateGroups(
      [
        game({ week: 1, seasonType: 3, scheduledAt: at(2026, 9, 6) }),
        game({ week: 1, scheduledAt: at(2026, 9, 5, 19) }),
        game({ week: 1, scheduledAt: at(2026, 9, 5, 15) }),
      ],
      "day"
    );
    expect(groups).toHaveLength(2);
    expect(groups[0].games).toHaveLength(2);
    expect(groups[0].title).toContain("September 5");
  });

  it("gives undated games a bucket of their own, last", () => {
    const groups = slateGroups(
      [
        game({ scheduledAt: "not a date" }),
        game({ scheduledAt: at(2026, 9, 5) }),
      ],
      "day"
    );
    expect(groups.map((g) => g.id)).toEqual(["day-2026-09-05", "day-tbd"]);
  });

  it("says which year once the date is in a different one", () => {
    const now = new Date(2026, 8, 9);
    expect(slateDayTitle(new Date(2026, 8, 5), now)).toBe(
      "Saturday, September 5"
    );
    expect(slateDayTitle(new Date(2019, 9, 2), now)).toBe(
      "Wednesday, October 2, 2019"
    );
  });
});

describe("no grouping", () => {
  it("is one unheaded chronological card", () => {
    const groups = slateGroups(
      [
        game({ week: 3, scheduledAt: at(2026, 9, 19) }),
        game({ week: 1, scheduledAt: at(2026, 9, 5) }),
      ],
      "none"
    );
    expect(groups).toHaveLength(1);
    expect(groups[0].title).toBe("");
    expect(groups[0].games).toHaveLength(2);
  });

  it("makes no card at all out of nothing", () => {
    expect(slateGroups([], "none")).toEqual([]);
  });
});

describe("the team filter", () => {
  it("keeps a team's games home and away", () => {
    const home = game({ home: georgia, away: alabama });
    const away = game({ home: alabama, away: georgia });
    const neither = game({ home: bills, away: chiefs });
    expect(gamesForTeam([home, away, neither], "61")).toEqual([home, away]);
  });

  it("treats no selection as the whole slate", () => {
    const games = [game({}), game({})];
    expect(gamesForTeam(games, undefined)).toEqual(games);
  });

  it("filters a team with no games to nothing", () => {
    expect(gamesForTeam([game({})], "9999")).toEqual([]);
  });
});

describe("the fold", () => {
  const now = new Date(2026, 8, 23, 12); // Wednesday, September 23 2026

  function week(number: number, day: number, status: GameStatus = "complete") {
    return game({
      week: number,
      scheduledAt: at(2026, 9, day),
      status,
    });
  }

  it("splits at the first card with football left in it", () => {
    const groups = slateGroups(
      [week(1, 5), week(2, 12), week(3, 19), week(4, 26, "scheduled")],
      "week"
    );
    const fold = foldSlate(groups, now);
    expect(fold.earlier.map((g) => g.title)).toEqual([
      "Week 1",
      "Week 2",
      "Week 3",
    ]);
    expect(fold.upcoming.map((g) => g.title)).toEqual(["Week 4"]);
  });

  it("folds nothing in a finished season", () => {
    const groups = slateGroups([week(1, 5), week(2, 12)], "week");
    const fold = foldSlate(groups, now);
    expect(fold.earlier).toEqual([]);
    expect(fold.upcoming).toHaveLength(2);
  });

  it("folds nothing in a season that hasn't started", () => {
    const groups = slateGroups(
      [
        game({ week: 1, scheduledAt: at(2026, 10, 3), status: "scheduled" }),
        game({ week: 2, scheduledAt: at(2026, 10, 10), status: "scheduled" }),
      ],
      "week"
    );
    expect(foldSlate(groups, now).earlier).toEqual([]);
  });

  it("never folds today's card away", () => {
    const groups = slateGroups(
      [week(1, 5), week(2, 12), week(3, 23)],
      "week"
    );
    const fold = foldSlate(groups, now);
    expect(fold.upcoming.map((g) => g.title)).toEqual(["Week 3"]);
  });

  it("only ever takes a prefix", () => {
    // Week 2 reads as spent, but it sits behind a week that doesn't — a
    // postponed game rescheduled forward leaves its old week short, and the
    // fold must not rearrange the season around it.
    const groups = slateGroups(
      [
        week(1, 5),
        game({ week: 2, scheduledAt: at(2026, 10, 31), status: "scheduled" }),
        week(3, 19),
      ],
      "week"
    );
    const fold = foldSlate(groups, now);
    expect(fold.earlier.map((g) => g.title)).toEqual(["Week 1"]);
    expect(fold.upcoming.map((g) => g.title)).toEqual(["Week 2", "Week 3"]);
  });

  it("never spends an undated card, so the fold stops where it stands", () => {
    const groups = slateGroups(
      [week(1, 5), game({ week: 1, seasonType: 3, scheduledAt: "TBA" })],
      "week"
    );
    const fold = foldSlate(groups, new Date(2026, 11, 25, 12));
    expect(fold.earlier.map((g) => g.id)).toEqual(["week-1"]);
    expect(fold.upcoming.map((g) => g.id)).toEqual(["week-postseason"]);
  });

  it("folds a day-grouped slate the same way", () => {
    const groups = slateGroups(
      [week(1, 5), week(2, 12), week(3, 26, "scheduled")],
      "day"
    );
    const fold = foldSlate(groups, now);
    expect(fold.earlier).toHaveLength(2);
    expect(fold.upcoming).toHaveLength(1);
  });

  it("never folds the ungrouped card — it is the whole season", () => {
    const groups = slateGroups([week(1, 5), week(2, 12)], "none");
    expect(foldSlate(groups, now).earlier).toEqual([]);
    expect(foldSlate(groups, now).upcoming).toHaveLength(1);
  });
});

describe("spent", () => {
  const now = new Date(2026, 8, 23, 9); // 9am Wednesday

  it("holds a result's slot for the day it was played in", () => {
    expect(isGameSpent(game({ scheduledAt: at(2026, 9, 23, 1), status: "complete" }), now))
      .toBe(false);
  });

  it("gives an overnight final six hours of grace", () => {
    const lateTuesday = game({
      scheduledAt: at(2026, 9, 22, 22),
      status: "complete",
    });
    expect(isGameSpent(lateTuesday, new Date(2026, 8, 23, 3))).toBe(false);
    expect(isGameSpent(lateTuesday, new Date(2026, 8, 23, 5))).toBe(true);
  });

  it("never spends a live game", () => {
    expect(
      isGameSpent(
        game({ scheduledAt: at(2026, 9, 22, 12), status: "in_progress" }),
        now
      )
    ).toBe(false);
  });

  it("never spends a game ESPN hasn't dated", () => {
    expect(isGameSpent(game({ scheduledAt: "TBA", status: "complete" }), now))
      .toBe(false);
  });
});
