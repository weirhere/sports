import { describe, it, expect } from "vitest";
import { migrateFavorites } from "./favorites-migration";

describe("migrateFavorites", () => {
  it("maps legacy mock ids to ESPN numeric strings", () => {
    expect(migrateFavorites(["t-1", "t-3"], []).teams).toEqual(["333", "96"]);
  });

  it("normalizes espn-prefixed ids", () => {
    expect(migrateFavorites(["espn-333"], []).teams).toEqual(["333"]);
  });

  it("passes raw numeric-string ids through", () => {
    expect(migrateFavorites(["2633"], []).teams).toEqual(["2633"]);
  });

  it("drops unknown team ids", () => {
    expect(migrateFavorites(["t-999", "garbage", ""], []).teams).toEqual([]);
  });

  it("dedupes — the mock carries duplicate espnIds, first wins", () => {
    // t-20 and t-23 both map to 2628; t-5 and t-26 both map to 2305.
    expect(migrateFavorites(["t-20", "t-23", "t-5", "t-26"], []).teams).toEqual(
      ["2628", "2305"]
    );
    expect(migrateFavorites(["333", "espn-333", "t-1"], []).teams).toEqual([
      "333",
    ]);
  });

  it("keeps only known FBS conference ids", () => {
    const { confs } = migrateFavorites(
      [],
      ["8", "5", "179", "banana", "80", ""]
    );
    // 179 is an FCS conference id, 80 is the FBS umbrella group — both drop.
    expect(confs).toEqual(["8", "5"]);
  });

  it("dedupes conference ids", () => {
    expect(migrateFavorites([], ["8", "8", "1"]).confs).toEqual(["8", "1"]);
  });

  it("is idempotent", () => {
    const first = migrateFavorites(["t-1", "espn-96", "2633"], ["8", "37"]);
    const second = migrateFavorites(first.teams, first.confs);
    expect(second).toEqual(first);
  });
});
