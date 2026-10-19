// The For you sheet's hidden set (2026-10-19) — the web twin of iOS
// `UIStateStore.newsHiddenTeams` and the `theForYouSheetHidesATeamAndRemembersIt`
// test in sportsTests/NewsTests.swift.

import { describe, it, expect } from "vitest";
import {
  NEWS_HIDDEN_TEAMS_KEY,
  readHiddenTeams,
  visibleFollowKeys,
  writeHiddenTeams,
} from "./news-filter";

function memoryStorage(initial: Record<string, string> = {}) {
  const store = new Map(Object.entries(initial));
  return {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, value: string) => void store.set(key, value),
    store,
  };
}

describe("the For you sheet's hidden set", () => {
  it("hides a team and remembers it", () => {
    const storage = memoryStorage();
    expect(readHiddenTeams(storage).size).toBe(0);
    writeHiddenTeams(storage, new Set(["nba:18"]));
    expect(storage.store.get(NEWS_HIDDEN_TEAMS_KEY)).toBe('["nba:18"]');
    // A relaunch reads it back.
    const again = readHiddenTeams(storage);
    expect(again.has("nba:18")).toBe(true);
    expect(again.has("nba:2")).toBe(false);
  });

  it("drops the hidden team from the follows For you is built from", () => {
    expect(visibleFollowKeys(["nba:18", "nba:2", "nfl:26"], new Set(["nba:18"]))).toEqual([
      "nba:2",
      "nfl:26",
    ]);
    // A hidden key nobody follows any more is simply never consulted.
    expect(visibleFollowKeys(["nba:2"], new Set(["nba:18"]))).toEqual(["nba:2"]);
  });

  it("shrugs off storage that throws or holds junk", () => {
    const throwing = {
      getItem: () => {
        throw new Error("blocked");
      },
      setItem: () => {
        throw new Error("blocked");
      },
    };
    expect(readHiddenTeams(throwing).size).toBe(0);
    expect(() => writeHiddenTeams(throwing, new Set(["nba:18"]))).not.toThrow();
    expect(readHiddenTeams(memoryStorage({ [NEWS_HIDDEN_TEAMS_KEY]: "{}" })).size).toBe(0);
    expect(readHiddenTeams(memoryStorage({ [NEWS_HIDDEN_TEAMS_KEY]: '[1,"nhl:21"]' }))).toEqual(
      new Set(["nhl:21"])
    );
    expect(readHiddenTeams(undefined).size).toBe(0);
  });
});
