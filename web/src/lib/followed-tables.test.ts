import { describe, expect, it } from "vitest";
import type { Game, GameTeam, Team } from "./types";
import type { League } from "./leagues";
import {
  moveAmongVisible,
  orderedTables,
  parseTableToken,
  tableLogoUrl,
  tableMatches,
  tableName,
  tableToken,
  type FollowedTable,
} from "./followed-tables";

function team(id: string, conferenceId: string, league: League): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name: "",
    school: "Team",
    abbreviation: "TM",
    conferenceId,
    conferenceName: "",
    logoUrl: "",
  };
}

function side(t: Team, ranking?: number): GameTeam {
  return { team: t, score: null, ranking };
}

function game(home: Team, away: Team, ranking?: number): Game {
  return {
    id: "g1",
    league: home.league,
    status: "scheduled",
    scheduledAt: "2026-09-05T19:30:00Z",
    venue: { name: "", city: "", state: "" },
    homeTeam: side(home, ranking),
    awayTeam: side(away),
    seasonYear: 2026,
    conferenceGame: false,
  };
}

const sec: FollowedTable = { kind: "conference", ref: { league: "cfb", id: 8 } };
const afc: FollowedTable = { kind: "conference", ref: { league: "nfl", id: 8 } };
const poll: FollowedTable = { kind: "poll", league: "cfb" };

describe("tokens", () => {
  it("round-trips, keeping the SEC and the AFC apart at group 8", () => {
    expect(tableToken(sec)).toBe("conf-cfb:8");
    expect(tableToken(afc)).toBe("conf-nfl:8");
    expect(tableToken(poll)).toBe("poll-cfb");
    for (const table of [sec, afc, poll]) {
      expect(parseTableToken(tableToken(table))).toEqual(table);
    }
  });

  it("rejects a token it can't place", () => {
    expect(parseTableToken("poll-mls")).toBeUndefined();
    expect(parseTableToken("conf-mls:8")).toBeUndefined();
    expect(parseTableToken("garbage")).toBeUndefined();
  });
});

describe("names and marks", () => {
  it("names each table", () => {
    expect(tableName(sec)).toBe("SEC");
    expect(tableName(afc)).toBe("AFC");
    expect(tableName(poll)).toBe("Top 25");
  });

  it("gives the poll its league's mark, not a trophy", () => {
    // "Top 25" never said whose, which is fine while one league polls and
    // confusing the moment a second one does (iOS, 2026-09-06).
    expect(tableLogoUrl(poll)).toContain("football-college");
  });
});

describe("claiming a game", () => {
  it("matches a conference directly", () => {
    const georgia = team("61", "8", "cfb");
    const alabama = team("333", "8", "cfb");
    expect(tableMatches(sec, game(georgia, alabama))).toBe(true);
  });

  it("walks a pro division up to its conference and its league", () => {
    // ESPN's NFL scoreboard gives a team its *division* id, so a followed
    // AFC only matches a Bills game if the walk-up happens.
    const bills = team("2", "4", "nfl"); // AFC East
    const chiefs = team("12", "6", "nfl"); // AFC West
    expect(tableMatches(afc, game(bills, chiefs))).toBe(true);
    const nfl: FollowedTable = {
      kind: "conference",
      ref: { league: "nfl", id: 9 },
    };
    expect(tableMatches(nfl, game(bills, chiefs))).toBe(true);
  });

  it("never matches across leagues at a colliding id", () => {
    const georgia = team("61", "8", "cfb");
    const alabama = team("333", "8", "cfb");
    expect(tableMatches(afc, game(georgia, alabama))).toBe(false);
  });

  it("claims any ranked participant for a poll, in that league only", () => {
    const georgia = team("61", "8", "cfb");
    const alabama = team("333", "8", "cfb");
    expect(tableMatches(poll, game(georgia, alabama, 3))).toBe(true);
    expect(tableMatches(poll, game(georgia, alabama))).toBe(false);
    const bills = team("2", "4", "nfl");
    const chiefs = team("12", "6", "nfl");
    expect(tableMatches(poll, game(bills, chiefs, 1))).toBe(false);
  });
});

describe("ordering", () => {
  it("falls back to the hub's own order before anyone drags anything", () => {
    // Polls first within a league, then groups widest first; leagues in
    // their own order.
    const tables = orderedTables({
      followedConferenceTokens: ["nfl:8", "cfb:15", "cfb:8"],
      followedPollLeagues: ["cfb"],
    });
    expect(tables.map(tableToken)).toEqual([
      "poll-cfb",
      "conf-cfb:8", // SEC, power4
      "conf-cfb:15", // MAC, group5
      "conf-nfl:8", // AFC
    ]);
  });

  it("honors a stored drag order, and lands a new follow at the end", () => {
    const tables = orderedTables({
      followedConferenceTokens: ["cfb:8", "cfb:15", "nfl:8"],
      followedPollLeagues: [],
      order: ["conf-nfl:8", "conf-cfb:15"],
    });
    expect(tables.map(tableToken)).toEqual([
      "conf-nfl:8",
      "conf-cfb:15",
      // Never dragged — so it sorts after the ones that were.
      "conf-cfb:8",
    ]);
  });

  it("ignores an order entry that is no longer followed", () => {
    const tables = orderedTables({
      followedConferenceTokens: ["cfb:8"],
      followedPollLeagues: [],
      order: ["conf-nfl:8", "conf-cfb:8"],
    });
    expect(tables.map(tableToken)).toEqual(["conf-cfb:8"]);
  });
});

describe("moving among the visible cards", () => {
  // The Following cards skip a followed table with no data, so a drop index
  // there is a slot among the cards on screen, not in the stored order.
  const poll: FollowedTable = { kind: "poll", league: "cfb" };
  const sec = parseTableToken("conf-cfb:8")!;
  const mac = parseTableToken("conf-cfb:15")!;
  const afc = parseTableToken("conf-nfl:8")!;

  it("keeps a hidden table in the order and doesn't shift the drop", () => {
    // Poll is followed but has no card.
    const next = moveAmongVisible([poll, sec, mac, afc], afc, 1, [sec, mac, afc]);
    expect(next).toEqual(["poll-cfb", "conf-cfb:8", "conf-nfl:8", "conf-cfb:15"]);
  });

  it("lands the past-the-end slot after the last card, ahead of a hidden one", () => {
    const next = moveAmongVisible([sec, mac, poll], sec, 1, [sec, mac]);
    expect(next).toEqual(["conf-cfb:15", "conf-cfb:8", "poll-cfb"]);
  });

  it("matches a plain move when nothing is hidden", () => {
    const all = [sec, mac, afc];
    expect(moveAmongVisible(all, sec, 2, all)).toEqual([
      "conf-cfb:15",
      "conf-nfl:8",
      "conf-cfb:8",
    ]);
    expect(moveAmongVisible(all, afc, 0, all)).toEqual([
      "conf-nfl:8",
      "conf-cfb:8",
      "conf-cfb:15",
    ]);
  });
});

