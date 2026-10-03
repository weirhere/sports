import { describe, it, expect } from "vitest";
import { foldDivisionTokens, migrateFavorites } from "./favorites-migration";

describe("migrateFavorites", () => {
  it("maps legacy mock ids to ESPN numeric strings", () => {
    expect(migrateFavorites(["t-1", "t-3"], []).teams).toEqual(["cfb:333", "cfb:96"]);
  });

  it("normalizes espn-prefixed ids", () => {
    expect(migrateFavorites(["espn-333"], []).teams).toEqual(["cfb:333"]);
  });

  it("passes raw numeric-string ids through", () => {
    expect(migrateFavorites(["2633"], []).teams).toEqual(["cfb:2633"]);
  });

  it("drops unknown team ids", () => {
    expect(migrateFavorites(["t-999", "garbage", ""], []).teams).toEqual([]);
  });

  it("dedupes — the mock carries duplicate espnIds, first wins", () => {
    // t-20 and t-23 both map to 2628; t-5 and t-26 both map to 2305.
    expect(migrateFavorites(["t-20", "t-23", "t-5", "t-26"], []).teams).toEqual(
      ["cfb:2628", "cfb:2305"]
    );
    expect(migrateFavorites(["333", "espn-333", "t-1"], []).teams).toEqual([
      "cfb:333",
    ]);
  });

  it("keeps only known FBS conference ids", () => {
    const { confs } = migrateFavorites(
      [],
      ["8", "5", "179", "banana", "80", ""]
    );
    // 179 is an FCS conference id, 80 is the FBS umbrella group — both drop.
    expect(confs).toEqual(["cfb:8", "cfb:5"]);
  });

  it("dedupes conference ids", () => {
    expect(migrateFavorites([], ["8", "8", "1"]).confs).toEqual(["cfb:8", "cfb:1"]);
  });

  it("is idempotent", () => {
    const first = migrateFavorites(["t-1", "espn-96", "2633"], ["8", "37"]);
    const second = migrateFavorites(first.teams, first.confs);
    expect(second).toEqual(first);
  });

  it("moves a pro division follow to its conference, first place wins", () => {
    // The Atlantic (1) and Central (2) are both the East (5).
    expect(
      migrateFavorites([], ["cfb:8", "nba:1", "nfl:7", "nba:2"]).confs
    ).toEqual(["cfb:8", "nba:5", "nfl:7"]);
  });
});

describe("foldDivisionTokens", () => {
  it("folds the Following drag order under its prefix", () => {
    expect(
      foldDivisionTokens(["poll-cfb", "conf-nba:4", "conf-nba:6", "conf-cfb:4"], "conf-")
    ).toEqual(["poll-cfb", "conf-nba:6", "conf-cfb:4"]);
  });

  it("is idempotent", () => {
    const once = foldDivisionTokens(["nhl:32", "nfl:4"]);
    expect(once).toEqual(["nhl:7", "nfl:8"]);
    expect(foldDivisionTokens(once)).toEqual(once);
  });
});
