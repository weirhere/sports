import { describe, it, expect } from "vitest";
import {
  RECENT_SEARCHES_KEY,
  RECENT_SEARCHES_LIMIT,
  parseRecents,
  readRecents,
  recentSearchId,
  recordRecent,
  removeRecent,
  writeRecents,
  type RecentSearch,
} from "./recent-searches";

const auburn: RecentSearch = { kind: "team", id: "2", league: "cfb" };
const bills: RecentSearch = { kind: "team", id: "2", league: "nfl" };
const sec: RecentSearch = { kind: "conference", id: 8, league: "cfb" };
const afc: RecentSearch = { kind: "conference", id: 8, league: "nfl" };
const mcdavid: RecentSearch = {
  kind: "player",
  id: "3895074",
  league: "nhl",
  name: "Connor McDavid",
  teamName: "Edmonton Oilers",
  teamId: "6",
  headshotUrl: "https://a.espncdn.com/i/headshots/nhl/players/full/3895074.png",
};
const game: RecentSearch = {
  kind: "game",
  id: "401",
  league: "nfl",
  day: "2026-09-27T17:00Z",
};

function memoryStorage(initial?: string) {
  const values = new Map<string, string>();
  if (initial !== undefined) values.set(RECENT_SEARCHES_KEY, initial);
  return {
    values,
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => {
      values.set(key, value);
    },
  };
}

describe("recentSearchId", () => {
  it("is league-qualified, so colliding ESPN ids stay two entries", () => {
    expect(recentSearchId(auburn)).not.toBe(recentSearchId(bills));
    expect(recentSearchId(sec)).not.toBe(recentSearchId(afc));
    expect(recentSearchId(game)).toBe("game.nfl.401");
  });
});

describe("recordRecent", () => {
  it("puts the newest entry first", () => {
    expect(recordRecent([auburn, sec], mcdavid)).toEqual([mcdavid, auburn, sec]);
  });

  it("moves a repeat to the front rather than duplicating it", () => {
    expect(recordRecent([auburn, sec, game], game)).toEqual([game, auburn, sec]);
  });

  it("matches a player by id, not by snapshot, so a club change reorders", () => {
    const traded = { ...mcdavid, teamName: "Somewhere Else", teamId: "99" };
    const next = recordRecent([auburn, mcdavid], traded);
    expect(next).toEqual([traded, auburn]);
  });

  it("keeps Auburn and the Bills apart", () => {
    expect(recordRecent([auburn], bills)).toEqual([bills, auburn]);
  });

  it("caps the list at ten", () => {
    let list: RecentSearch[] = [];
    for (let i = 0; i < 15; i++) {
      list = recordRecent(list, { kind: "team", id: String(i), league: "nba" });
    }
    expect(list).toHaveLength(RECENT_SEARCHES_LIMIT);
    expect(list[0]).toEqual({ kind: "team", id: "14", league: "nba" });
    expect(list.at(-1)).toEqual({ kind: "team", id: "5", league: "nba" });
  });
});

describe("removeRecent", () => {
  it("drops only the matching entry", () => {
    expect(removeRecent([auburn, bills, sec], bills)).toEqual([auburn, sec]);
  });

  it("matches a drifted player snapshot by id", () => {
    const drifted = { ...mcdavid, name: "C. McDavid" };
    expect(removeRecent([mcdavid, sec], drifted)).toEqual([sec]);
  });
});

describe("parseRecents", () => {
  it("round-trips every kind", () => {
    const list = [auburn, sec, mcdavid, game];
    expect(parseRecents(JSON.stringify(list))).toEqual(list);
  });

  it("reads garbage as empty rather than throwing", () => {
    expect(parseRecents(null)).toEqual([]);
    expect(parseRecents("")).toEqual([]);
    expect(parseRecents("{not json")).toEqual([]);
    expect(parseRecents(JSON.stringify({ kind: "team" }))).toEqual([]);
  });

  it("drops malformed entries and keeps the rest", () => {
    const raw = JSON.stringify([
      auburn,
      { kind: "team", id: "", league: "cfb" },
      { kind: "team", id: "5", league: "mlb" },
      { kind: "conference", id: "8", league: "cfb" },
      { kind: "player", id: "1", league: "nfl", name: "No Team Id" },
      { kind: "planet", id: "3", league: "nfl" },
      null,
      sec,
    ]);
    expect(parseRecents(raw)).toEqual([auburn, sec]);
  });

  it("dedupes and caps what an older or hand-edited list stored", () => {
    const many = Array.from({ length: 14 }, (_, i) => ({
      kind: "team",
      id: String(i),
      league: "nhl",
    }));
    const raw = JSON.stringify([auburn, auburn, ...many]);
    const parsed = parseRecents(raw);
    expect(parsed).toHaveLength(RECENT_SEARCHES_LIMIT);
    expect(parsed.filter((e) => recentSearchId(e) === recentSearchId(auburn))).toHaveLength(1);
  });
});

describe("storage access", () => {
  it("writes and reads back through the storage key", () => {
    const storage = memoryStorage();
    writeRecents(storage, [mcdavid, auburn]);
    expect(readRecents(storage)).toEqual([mcdavid, auburn]);
  });

  it("survives storage that throws on read and on write", () => {
    const hostile = {
      getItem: () => {
        throw new Error("SecurityError");
      },
      setItem: () => {
        throw new Error("QuotaExceededError");
      },
    };
    expect(readRecents(hostile)).toEqual([]);
    expect(() => writeRecents(hostile, [auburn])).not.toThrow();
  });

  it("treats missing storage as empty", () => {
    expect(readRecents(undefined)).toEqual([]);
    expect(() => writeRecents(undefined, [auburn])).not.toThrow();
  });
});
