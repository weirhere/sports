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
  transformBoxScore,
  transformPlays,
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

const games = transformScoreboard(scoreboard.events ?? [], "cfb");
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
    expect(transformEvent(event, "cfb")?.seasonType).toBe(3);
  });

  it("finds the record by type 'total' or name 'overall'", () => {
    const byType = makeEvent();
    byType.competitions![0].competitors![0].records = [
      { name: "Home", type: "home", summary: "1-0" },
      { name: "YTD", type: "total", summary: "3-1" },
    ];
    expect(transformEvent(byType, "cfb")?.homeTeam.record).toBe("3-1");

    const byName = makeEvent();
    byName.competitions![0].competitors![0].records = [
      { name: "overall", summary: "2-2" },
    ];
    expect(transformEvent(byName, "cfb")?.homeTeam.record).toBe("2-2");
  });

  it("clamps curated ranks to 1…25", () => {
    const event = makeEvent();
    event.competitions![0].competitors![0].curatedRank = { current: 99 };
    event.competitions![0].competitors![1].curatedRank = { current: 14 };
    const game = transformEvent(event, "cfb");
    expect(game?.homeTeam.ranking).toBeUndefined();
    expect(game?.awayTeam.ranking).toBe(14);
  });

  it("normalizes ESPN's empty broadcast string to undefined", () => {
    const event = makeEvent();
    event.competitions![0].broadcast = "";
    expect(transformEvent(event, "cfb")?.broadcast).toBeUndefined();

    event.competitions![0].broadcasts = [{ names: ["ESPN2"] }];
    expect(transformEvent(event, "cfb")?.broadcast).toBe("ESPN2");
  });

  it("drops malformed events instead of throwing", () => {
    expect(transformEvent({ id: "x" }, "cfb")).toBeNull();
    expect(transformEvent(makeEvent({ id: undefined }), "cfb")).toBeNull();
    const oneSided = makeEvent();
    oneSided.competitions![0].competitors = [
      { homeAway: "home", team: { id: "10", location: "Home U" } },
    ];
    expect(transformEvent(oneSided, "cfb")).toBeNull();
    expect(
      transformScoreboard([{ id: "x" }, makeEvent()], "cfb").map((g) => g.id)
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
  const groups = transformStandings(standings, "cfb");

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
    const [sec] = transformStandings(seeded, "cfb");
    expect(sec.entries.map((e) => e.team.school)).toEqual(["First", "Second"]);
  });
});

describe("transformConferenceTeams", () => {
  const groups = transformConferenceTeams(standings, "cfb");

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
    const polls = transformPolls(rankings, "cfb");
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
    const current = transformTeamSchedule(schedule2026, "cfb");
    expect(current.year).toBe(2026);
    expect(current.record).toBe("0-0");
    expect(current.standing).toBe("1st in SEC");

    // The 2025 fixture: ESPN's current season is 2026, so its summaries
    // describe the wrong season and must not survive.
    const past = transformTeamSchedule(schedule2025, "cfb");
    expect(past.year).toBe(2025);
    expect(past.record).toBeUndefined();
    expect(past.standing).toBeUndefined();
  });

  it("derives a past season's record from final results", () => {
    // Alabama in the trimmed 2025 events: L @ Florida State, W ULM, W Wisconsin.
    const past = transformTeamSchedule(schedule2025, "cfb");
    expect(past.derivedRecord).toBe("2-1");
  });

  it("reads the schedule endpoint's score OBJECT", () => {
    const past = transformTeamSchedule(schedule2025, "cfb");
    const opener = past.games.find((g) => g.id === "401752665");
    expect(opener?.homeTeam.score).toBe(31);
    expect(opener?.awayTeam.score).toBe(17);
    expect(opener?.awayTeam.ranking).toBe(8);
    expect(opener?.homeTeam.ranking).toBeUndefined(); // 99 clamps away
  });

  it("resolves the team's conference through the groups rule", () => {
    const current = transformTeamSchedule(schedule2026, "cfb");
    expect(current.team?.id).toBe("333");
    // groups.isConference true → the group IS the conference (SEC, 8).
    expect(current.team?.conferenceId).toBe("8");
    expect(current.team?.conferenceName).toBe("SEC");
  });

  it("sorts games by date", () => {
    const past = transformTeamSchedule(schedule2025, "cfb");
    const times = past.games.map((g) => Date.parse(g.scheduledAt));
    expect(times).toEqual([...times].sort((a, b) => a - b));
  });

  it("stamps each phase's events with its own season type", () => {
    // The three phases arrive as three separate requests, and each one has
    // to say which it is: a preseason game filed as postseason reads as a
    // game that counted, in the wrong card, at the wrong end of the season.
    const events = schedule2025.events ?? [];
    const withPhases = transformTeamSchedule(schedule2025, "cfb", {
      preseason: events.slice(0, 1),
      postseason: events.slice(1, 2),
    });
    const types = withPhases.games.map((game) => game.seasonType);
    expect(types.filter((type) => type === 1)).toHaveLength(1);
    expect(types.filter((type) => type === 3)).toHaveLength(1);
    expect(types.filter((type) => type === 2)).toHaveLength(events.length);
  });
});

describe("a season that hasn't opened has no numbers", () => {
  // ESPN rolls its season pointer the moment the last one ends and keeps
  // serving the old table underneath it: probed live 2026-09-09, the NBA
  // standings were stamped 2026-27 and full of 2025-26 results three weeks
  // before a ball was tipped.
  const response = {
    season: { year: 2027, startDate: "2026-09-30T07:00Z" },
    children: [
      {
        id: 5,
        name: "Eastern Conference",
        standings: {
          entries: [
            {
              team: { id: "2", location: "Boston", abbreviation: "BOS" },
              stats: [
                { type: "vsconf", summary: "36-16" },
                { type: "total", summary: "56-26" },
                { type: "winpercent", value: 0.68 },
              ],
            },
          ],
        },
      },
    ],
  } as unknown as EspnStandingsResponse;

  it("keeps the roster and drops the records", () => {
    // Who is in this division is true all summer; only the numbers are
    // last season's.
    const [table] = transformStandings(response, "nba");
    const [entry] = table.entries;
    expect(entry.team.school).toBe("Boston");
    expect(entry.conferenceRecord).toBeUndefined();
    expect(entry.overallRecord).toBeUndefined();
    expect(entry.overallWins).toBe(0);
  });

  it("keeps them once the season has opened", () => {
    const started = {
      ...response,
      season: { ...response.season, startDate: "2026-09-01T07:00Z" },
    } as EspnStandingsResponse;
    const [entry] = transformStandings(started, "nba")[0].entries;
    expect(entry.conferenceRecord).toBe("36-16");
    expect(entry.overallRecord).toBe("56-26");
  });

  it("keeps them when ESPN ships no start date at all", () => {
    // Absence must never blank a table — every football response we have
    // read ships one, but the rule can't depend on that.
    const undated = { ...response, season: undefined } as EspnStandingsResponse;
    expect(transformStandings(undated, "nba")[0].entries[0].conferenceRecord).toBe(
      "36-16"
    );
  });
});

describe("the box score carries its own columns", () => {
  // The whole rule: a live `passing` group ships five columns and the same
  // group ships six once the game is final (QBR only lands at the end), so a
  // schema named in code misaligns every row mid-game.
  const group = (over: Record<string, unknown> = {}) => ({
    name: "passing",
    text: "Miami Passing",
    labels: ["C/ATT", "YDS", "TD"],
    athletes: [
      {
        athlete: { id: "1", displayName: "A. Quarterback", jersey: "5" },
        stats: ["11/19", "162", "2"],
      },
    ],
    totals: ["15/26", "199", "2"],
    ...over,
  });

  it("reads the columns off the payload", () => {
    const teams = transformBoxScore(
      { players: [{ team: { id: "2390", displayName: "Miami" }, statistics: [group()] }] },
      "cfb"
    );
    expect(teams).toHaveLength(1);
    expect(teams[0].categories[0].columns).toEqual(["C/ATT", "YDS", "TD"]);
    expect(teams[0].categories[0].players[0].stats).toEqual(["11/19", "162", "2"]);
  });

  it("drops a row whose stat count doesn't match the header", () => {
    const teams = transformBoxScore(
      {
        players: [
          {
            team: { id: "2390" },
            statistics: [
              group({
                athletes: [
                  { athlete: { id: "1", displayName: "Short" }, stats: ["11/19", "162"] },
                  { athlete: { id: "2", displayName: "Right" }, stats: ["9/12", "88", "1"] },
                ],
              }),
            ],
          },
        ],
      },
      "cfb"
    );
    expect(teams[0].categories[0].players.map((p) => p.name)).toEqual(["Right"]);
  });

  it("drops a totals row that doesn't match, keeping the category", () => {
    const teams = transformBoxScore(
      {
        players: [
          { team: { id: "2390" }, statistics: [group({ totals: ["15/26", "199"] })] },
        ],
      },
      "cfb"
    );
    expect(teams[0].categories[0].totals).toEqual([]);
    expect(teams[0].categories[0].players).toHaveLength(1);
  });

  it("keeps a group ESPN gave no name — basketball ships exactly one", () => {
    // Requiring a name dropped every NBA box score on the floor, invisibly,
    // since an empty box score is how the tab hides itself.
    const teams = transformBoxScore(
      {
        players: [
          {
            team: { id: "2" },
            statistics: [
              {
                labels: ["MIN", "PTS", "REB"],
                athletes: [
                  { athlete: { id: "9", displayName: "A. Guard" }, stats: ["34", "28", "5"] },
                ],
              },
            ],
          },
        ],
      },
      "nba"
    );
    expect(teams[0].categories[0].label).toBe("Players");
    expect(teams[0].categories[0].players).toHaveLength(1);
  });

  it("strips the team prefix ESPN puts on a group heading", () => {
    const teams = transformBoxScore(
      {
        players: [
          { team: { id: "2390", displayName: "Miami" }, statistics: [group()] },
        ],
      },
      "cfb"
    );
    expect(teams[0].categories[0].label).toBe("Passing");
  });

  it("drops a category nobody recorded anything in", () => {
    // ESPN ships all ten for every game — an interception group with no
    // interceptions isn't a section, it's noise.
    const teams = transformBoxScore(
      {
        players: [
          {
            team: { id: "2390" },
            statistics: [group({ athletes: [] }), group({ name: "rushing", text: undefined })],
          },
        ],
      },
      "cfb"
    );
    expect(teams[0].categories.map((c) => c.id)).toEqual(["rushing"]);
  });

  it("un-camel-cases a group name with no heading", () => {
    const teams = transformBoxScore(
      {
        players: [
          {
            team: { id: "2390" },
            statistics: [group({ name: "kickReturns", text: undefined })],
          },
        ],
      },
      "cfb"
    );
    expect(teams[0].categories[0].label).toBe("Kick Returns");
  });
});

describe("a scoring play says whose points those were", () => {
  const play = (over: Record<string, unknown>) => ({
    id: String(Math.random()),
    scoringPlay: false,
    ...over,
  });

  it("reads the side off the change in the running score", () => {
    // Not off the team that ran the play: a pick six and a kick return both
    // score for the side that wasn't on offense.
    const plays = transformPlays([
      play({ awayScore: 0, homeScore: 0 }),
      play({ scoringPlay: true, awayScore: 7, homeScore: 0 }),
      play({ scoringPlay: true, awayScore: 7, homeScore: 7 }),
    ]);
    expect(plays.map((p) => p.scoringSide)).toEqual([
      undefined,
      "away",
      "home",
    ]);
  });

  it("claims no side for a scoring play with no numbers to read", () => {
    const plays = transformPlays([
      play({ awayScore: 0, homeScore: 0 }),
      play({ scoringPlay: true }),
    ]);
    expect(plays[1].scoringSide).toBeUndefined();
  });

  it("claims no side for the very first play, having nothing to compare", () => {
    const plays = transformPlays([
      play({ scoringPlay: true, awayScore: 7, homeScore: 0 }),
    ]);
    expect(plays[0].scoringSide).toBeUndefined();
  });

  it("carries the spot and the down a play left behind", () => {
    const plays = transformPlays([
      play({
        text: "pass complete for 11 yards",
        period: { number: 2 },
        clock: { displayValue: "5:24" },
        start: { downDistanceText: "1st & 10 at IU 5" },
        end: { shortDownDistanceText: "2nd & 4", possessionText: "WSU 26", yardsToEndzone: 26 },
      }),
    ]);
    expect(plays[0]).toMatchObject({
      period: 2,
      clock: "5:24",
      downDistanceText: "1st & 10 at IU 5",
      nextDownDistanceText: "2nd & 4",
      possessionText: "WSU 26",
      yardsToEndzone: 26,
    });
  });
});
