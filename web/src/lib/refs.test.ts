import { describe, it, expect } from "vitest";
import {
  conferenceToken,
  followKey,
  followedLeagues,
  followedTeamIds,
  parseConferenceToken,
  parseFollowKey,
  preferredLeague,
} from "./refs";

describe("follow keys", () => {
  it("qualifies a team by its league", () => {
    expect(followKey({ league: "cfb", teamId: "130" })).toBe("cfb:130");
    expect(followKey({ league: "nfl", teamId: "26" })).toBe("nfl:26");
  });

  it("keeps colliding ESPN ids apart", () => {
    // These are the real collisions, not hypotheticals: id 5 is UAB and the
    // Browns, id 2 is Auburn and the Bills, id 26 is UCLA and the Seahawks.
    // 20 of the NFL's 32 ids have a college twin.
    const stored = ["cfb:5", "nfl:5"];
    expect(followedTeamIds(stored, "cfb")).toEqual(new Set(["5"]));
    expect(followedTeamIds(stored, "nfl")).toEqual(new Set(["5"]));
    expect(new Set(stored).size).toBe(2);
  });

  it("round-trips", () => {
    const ref = { league: "nba" as const, teamId: "17" };
    expect(parseFollowKey(followKey(ref))).toEqual(ref);
  });

  it("reads a bare id as college football", () => {
    // Pre-axis keys, and anything that escaped the migration.
    expect(parseFollowKey("130")).toEqual({ league: "cfb", teamId: "130" });
  });

  it("fails a malformed key rather than resolving a plausible wrong one", () => {
    // "nfl:" must not parse as a *college* team named "nfl", and ":26"
    // must not parse as college team 26.
    expect(parseFollowKey("nfl:")).toBeUndefined();
    expect(parseFollowKey(":26")).toBeUndefined();
    expect(parseFollowKey("")).toBeUndefined();
    expect(parseFollowKey("xfl:1")).toBeUndefined();
  });
});

describe("conference tokens", () => {
  it("keeps the SEC and the AFC apart at group 8", () => {
    expect(conferenceToken({ league: "cfb", id: 8 })).toBe("cfb:8");
    expect(conferenceToken({ league: "nfl", id: 8 })).toBe("nfl:8");
  });

  it("reads a bare group id as college football's", () => {
    expect(parseConferenceToken("8")).toEqual({ league: "cfb", id: 8 });
  });

  it("rejects a token whose league it doesn't know", () => {
    expect(parseConferenceToken("mls:8")).toBeUndefined();
  });
});

describe("fan-out helpers", () => {
  it("names only the leagues a follow set touches", () => {
    // Every caller that fans out per league asks this first, so a
    // college-football-only user never pays for an NFL request.
    expect(followedLeagues(["cfb:130", "cfb:61"])).toEqual(["cfb"]);
    expect(followedLeagues(["nhl:1", "cfb:130"])).toEqual(["cfb", "nhl"]);
    expect(followedLeagues([])).toEqual([]);
  });

  it("ignores keys it can't parse", () => {
    expect(followedLeagues(["cfb:130", "junk:1", ""])).toEqual(["cfb"]);
  });

  it("picks the league you follow most, and nothing on a tie", () => {
    // Search's ranking tiebreak. It replaced an app-wide "current league"
    // scope: with every league on the page at once, "the league you follow
    // most" beats "the tab you last tapped".
    expect(preferredLeague(["cfb:1", "cfb:2", "nfl:1"])).toBe("cfb");
    expect(preferredLeague(["cfb:1", "nfl:1"])).toBeUndefined();
    expect(preferredLeague([])).toBeUndefined();
  });
});
