import { describe, it, expect } from "vitest";
import {
  FBS_GROUP_ID,
  conferenceName,
  tier,
  orderedIds,
  conferenceLogoUrl,
  titleGameIsTopTwo,
} from "./conferences";

describe("conference registry", () => {
  it("knows the FBS umbrella group", () => {
    expect(FBS_GROUP_ID).toBe(80);
  });

  it("names known ids and degrades unknowns to Other", () => {
    expect(conferenceName(8)).toBe("SEC");
    expect(conferenceName(15)).toBe("MAC");
    expect(conferenceName(179)).toBe("Other");
    expect(conferenceName(undefined)).toBe("Other");
  });

  it("assigns tiers", () => {
    expect(tier(1)).toBe("power4");
    expect(tier(4)).toBe("power4");
    expect(tier(5)).toBe("power4");
    expect(tier(8)).toBe("power4");
    expect(tier(18)).toBe("independent");
    expect(tier(37)).toBe("group5");
    expect(tier(999)).toBe("other");
  });

  it("orders P4 → G5 → Independents, alphabetical within tiers", () => {
    expect(orderedIds).toEqual([1, 4, 5, 8, 151, 12, 15, 17, 9, 37, 18]);
  });

  it("builds conference logo URLs from the slug map", () => {
    expect(conferenceLogoUrl(8)).toBe(
      "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/sec.png"
    );
    expect(conferenceLogoUrl(999)).toBeUndefined();
  });

  it("gates the title-game top-two claim per conference era", () => {
    expect(titleGameIsTopTwo(8, 2024)).toBe(true);
    expect(titleGameIsTopTwo(8, 2023)).toBe(false);
    expect(titleGameIsTopTwo(37, 2025)).toBe(false); // Sun Belt divisional
    expect(titleGameIsTopTwo(37, 2026)).toBe(true);
    expect(titleGameIsTopTwo(18, 2026)).toBe(false); // no title game
    expect(titleGameIsTopTwo(999, 2026)).toBe(false);
  });
});
