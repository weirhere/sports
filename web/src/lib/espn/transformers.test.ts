import { describe, it, expect } from "vitest";
import scoreboardJson from "./__fixtures__/scoreboard.json";
import standingsJson from "./__fixtures__/standings.json";
import rankingsJson from "./__fixtures__/rankings.json";
import schedule2026Json from "./__fixtures__/schedule-2026.json";
import schedule2025Json from "./__fixtures__/schedule-2025.json";
import type {
  EspnScoreboardResponse,
  EspnStandingsResponse,
  EspnRankingsResponse,
  EspnScheduleResponse,
  EspnEvent,
  EspnStatus,
} from "./types";
import {
  mapStatus,
  transformEvent,
  transformScoreboard,
  transformCalendar,
  transformStandings,
  transformConferenceTeams,
  transformPolls,
  transformTeamSchedule,
} from "./transformers";

const scoreboard = scoreboardJson as unknown as EspnScoreboardResponse;
const standings = standingsJson as unknown as EspnStandingsResponse;
const rankings = rankingsJson as unknown as EspnRankingsResponse;
const schedule2026 = schedule2026Json as unknown as EspnScheduleResponse;
const schedule2025 = schedule2025Json as unknown as EspnScheduleResponse;

/** Minimal well-formed event for micro-cases. */
function makeEvent(overrides: Partial<EspnEvent> = {}): EspnEvent {
  return {
    id: "1",
    date: "2026-09-05T16:00Z",
    season: { year: 2026, type: 2 },
    week: { number: 1 },
    competitions: [
      {
        timeValid: true,
        competitors: [
          { homeAway: "home", team: { id: "10", location: "Home U" } },
          { homeAway: "away", team: { id: "20", location: "Away U" } },
        ],
      },
    ],
    status: {
      type: { state: "pre", name: "STATUS_SCHEDULED", completed: false },
    },
    ...overrides,
  };
}

const games = transformScoreboard(scoreboard.events ?? []);
const byId = (id: string) => games.find((g) => g.id === id);

describe("status mapping (state first)", () => {
  it("maps the fixture's final and scheduled events", () => {
    expect(byId("401864494")?.status).toBe("complete");
    expect(byId("401858423")?.status).toBe("scheduled");
  });

  it("maps halftime from the type name within state 'in'", () => {
    const half = byId("9990001");
    expect(half?.status).toBe("halftime");
    expect(half?.livePhase).toBe("halftime");
  });

  it("keeps an unknown live status name live — never scheduled", () => {
    const live = byId("9990003");
    expect(live?.status).toBe("in_progress");
    expect(live?.livePhase).toBe("playing");
  });

  it("maps end-of-period", () => {
    const status: EspnStatus = {
      displayClock: "0:00",
      period: 1,
      type: { state: "in", name: "STATUS_END_PERIOD" },
    };
    expect(mapStatus(status)).toEqual({
      status: "end_period",
      livePhase: "endOfPeriod",
    });
  });

  it("maps postponed and cancelled by name within non-live states", () => {
    expect(
      mapStatus({ type: { state: "post", name: "STATUS_POSTPONED" } }).status
    ).toBe("postponed");
    expect(
      mapStatus({ type: { state: "post", name: "STATUS_CANCELED" } }).status
    ).toBe("cancelled");
  });
});

describe("transformEvent", () => {
  it("maps timeValid: false to timeTBD", () => {
    expect(byId("9990002")?.timeTBD).toBe(true);
    expect(byId("401858423")?.timeTBD).toBe(false);
  });

  it("carries the event's season type so a title game stays out of Week 1", () => {
    const event = makeEvent({ season: { year: 2026, type: 3 } });
    expect(transformEvent(event)?.seasonType).toBe(3);
  });

  it("finds the record by type 'total' or name 'overall'", () => {
    const byType = makeEvent();
    byType.competitions![0].competitors![0].records = [
      { name: "Home", type: "home", summary: "1-0" },
      { name: "YTD", type: "total", summary: "3-1" },
    ];
    expect(transformEvent(byType)?.homeTeam.record).toBe("3-1");

    const byName = makeEvent();
    byName.competitions![0].competitors![0].records = [
      { name: "overall", summary: "2-2" },
    ];
    expect(transformEvent(byName)?.homeTeam.record).toBe("2-2");
  });

  it("clamps curated ranks to 1…25", () => {
    const event = makeEvent();
    event.competitions![0].competitors![0].curatedRank = { current: 99 };
    event.competitions![0].competitors![1].curatedRank = { current: 14 };
    const game = transformEvent(event);
    expect(game?.homeTeam.ranking).toBeUndefined();
    expect(game?.awayTeam.ranking).toBe(14);
  });

  it("normalizes ESPN's empty broadcast string to undefined", () => {
    const event = makeEvent();
    event.competitions![0].broadcast = "";
    expect(transformEvent(event)?.broadcast).toBeUndefined();

    event.competitions![0].broadcasts = [{ names: ["ESPN2"] }];
    expect(transformEvent(event)?.broadcast).toBe("ESPN2");
  });

  it("drops malformed events instead of throwing", () => {
    expect(transformEvent({ id: "x" })).toBeNull();
    expect(transformEvent(makeEvent({ id: undefined }))).toBeNull();
    const oneSided = makeEvent();
    oneSided.competitions![0].competitors = [
      { homeAway: "home", team: { id: "10", location: "Home U" } },
    ];
    expect(transformEvent(oneSided)).toBeNull();
    expect(
      transformScoreboard([{ id: "x" }, makeEvent()]).map((g) => g.id)
    ).toEqual(["1"]);
  });
});

describe("transformCalendar", () => {
  const slots = transformCalendar(scoreboard);

  it("parses regular and postseason periods, skipping the off-season", () => {
    expect(slots).toHaveLength(17);
    expect(slots.every((s) => s.seasonType === 2 || s.seasonType === 3)).toBe(
      true
    );
  });

  it("compacts regular-week short labels and keeps postseason names", () => {
    expect(slots[0]).toMatchObject({
      id: "2-1",
      label: "Week 1",
      shortLabel: "Wk 1",
      seasonType: 2,
      value: 1,
      isPostseason: false,
    });
    const cfpSlot = slots.find((s) => s.id === "3-999");
    expect(cfpSlot).toMatchObject({ label: "CFP", isPostseason: true });
  });
});

describe("transformStandings", () => {
  const groups = transformStandings(standings);

  it("orders groups tier-then-name and keeps empty conferences", () => {
    expect(groups.map((g) => g.name)).toEqual(["SEC", "American", "Sun Belt"]);
    expect(groups[2].entries).toEqual([]);
  });

  it("keeps ESPN's payload order when seeds are incomplete", () => {
    // The American's trimmed entries carry seeds 1,0,0,0 — incomplete, so
    // payload order survives. Never sorted from records.
    const american = groups.find((g) => g.id === "151");
    expect(american?.entries.map((e) => e.team.school)).toEqual([
      "Memphis",
      "UAB",
      "South Florida",
      "East Carolina",
    ]);
  });

  it("carries the record display strings", () => {
    const memphis = groups
      .find((g) => g.id === "151")
      ?.entries.find((e) => e.team.school === "Memphis");
    expect(memphis?.overallRecord).toBe("1-0");
    expect(memphis?.conferenceRecord).toBe("0-0");
    expect(memphis?.overallWins).toBe(1);
    expect(memphis?.overallLosses).toBe(0);
  });

  it("sorts by playoffSeed when seeds are complete and unique", () => {
    const seeded: EspnStandingsResponse = {
      children: [
        {
          id: "8",
          standings: {
            entries: [
              {
                team: { id: "1", location: "Second" },
                stats: [{ type: "playoffseed", value: 2 }],
              },
              {
                team: { id: "2", location: "First" },
                stats: [{ type: "playoffseed", value: 1 }],
              },
            ],
          },
        },
      ],
    };
    const [sec] = transformStandings(seeded);
    expect(sec.entries.map((e) => e.team.school)).toEqual(["First", "Second"]);
  });
});

describe("transformConferenceTeams", () => {
  const groups = transformConferenceTeams(standings);

  it("keeps empty conferences — ESPN ships the Sun Belt with zero entries", () => {
    // Dropping the empty group would list 10 FBS conferences instead of 11.
    expect(groups.map((g) => g.name)).toEqual(["SEC", "American", "Sun Belt"]);
    const sunBelt = groups.find((g) => g.id === "37");
    expect(sunBelt?.teams).toEqual([]);
  });

  it("sorts rosters alphabetically by school", () => {
    const american = groups.find((g) => g.id === "151");
    const schools = american?.teams.map((t) => t.school) ?? [];
    expect(schools).toEqual([...schools].sort((a, b) => (a < b ? -1 : 1)));
    expect(schools.length).toBeGreaterThan(0);
  });
});

describe("transformPolls", () => {
  it("maps every poll with its ranks", () => {
    const polls = transformPolls(rankings);
    expect(polls).toHaveLength(2);
    expect(polls[0].name).toBe("AP Top 25");
    expect(polls[0].headline).toBe("2026 AP Poll: Preseason");
    expect(polls[0].ranks[0]).toMatchObject({
      rank: 1,
      record: "0-0",
    });
    expect(polls[0].ranks[0].team.school).toBe("Ohio State");
  });
});

describe("transformTeamSchedule", () => {
  it("trusts recordSummary/standingSummary only when seasons match", () => {
    // The 2026 fixture: season.year === requestedSeason.year.
    const current = transformTeamSchedule(schedule2026);
    expect(current.year).toBe(2026);
    expect(current.record).toBe("0-0");
    expect(current.standing).toBe("1st in SEC");

    // The 2025 fixture: ESPN's current season is 2026, so its summaries
    // describe the wrong season and must not survive.
    const past = transformTeamSchedule(schedule2025);
    expect(past.year).toBe(2025);
    expect(past.record).toBeUndefined();
    expect(past.standing).toBeUndefined();
  });

  it("derives a past season's record from final results", () => {
    // Alabama in the trimmed 2025 events: L @ Florida State, W ULM, W Wisconsin.
    const past = transformTeamSchedule(schedule2025);
    expect(past.derivedRecord).toBe("2-1");
  });

  it("reads the schedule endpoint's score OBJECT", () => {
    const past = transformTeamSchedule(schedule2025);
    const opener = past.games.find((g) => g.id === "401752665");
    expect(opener?.homeTeam.score).toBe(31);
    expect(opener?.awayTeam.score).toBe(17);
    expect(opener?.awayTeam.ranking).toBe(8);
    expect(opener?.homeTeam.ranking).toBeUndefined(); // 99 clamps away
  });

  it("resolves the team's conference through the groups rule", () => {
    const current = transformTeamSchedule(schedule2026);
    expect(current.team?.id).toBe("333");
    // groups.isConference true → the group IS the conference (SEC, 8).
    expect(current.team?.conferenceId).toBe("8");
    expect(current.team?.conferenceName).toBe("SEC");
  });

  it("sorts games by date", () => {
    const past = transformTeamSchedule(schedule2025);
    const times = past.games.map((g) => Date.parse(g.scheduledAt));
    expect(times).toEqual([...times].sort((a, b) => a - b));
  });
});
