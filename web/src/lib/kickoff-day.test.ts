import { describe, it, expect, afterAll } from "vitest";
import { parseKickoff, placeholderKickoff } from "./format";

// The zones a US audience actually reads this app in. Hawaii is the worst
// case at UTC-10: midnight Eastern is 6pm the *previous* day there.
const ZONES = [
  "America/New_York",
  "America/Chicago",
  "America/Denver",
  "America/Los_Angeles",
  "America/Anchorage",
  "Pacific/Honolulu",
];

const ORIGINAL_TZ = process.env.TZ;
afterAll(() => {
  process.env.TZ = ORIGINAL_TZ;
});

function inZone<T>(zone: string, body: () => T): T {
  process.env.TZ = zone;
  try {
    return body();
  } finally {
    process.env.TZ = ORIGINAL_TZ;
  }
}

// ESPN's literal sentinel for an unannounced kickoff: midnight Eastern on
// the game's day, flagged `timeValid: false`. Reproduced live — 41 of the
// 71 games in one late-September window carried this exact instant.
const SENTINEL = "2026-09-26T04:00:00Z"; // midnight ET, Sat Sep 26

describe("unannounced kickoffs land on the right day", () => {
  it("keeps the Eastern day in every US zone", () => {
    // This is the whole bug: a raw parse of the sentinel reads as Sep 25
    // everywhere west of Eastern — four of the six zones below — so a TBD
    // game filed a day early for most of the country.
    for (const zone of ZONES) {
      const day = inZone(zone, () =>
        placeholderKickoff(new Date(SENTINEL)).getDate()
      );
      expect(day, `${zone} should read the sentinel as Sep 26`).toBe(26);
    }
  });

  it("proves the raw parse is wrong where the fix matters", () => {
    // Guards the test itself: if this ever stops failing, the sentinel
    // stopped being a sentinel and the test above proves nothing.
    const raw = inZone("America/Los_Angeles", () =>
      new Date(SENTINEL).getDate()
    );
    expect(raw).toBe(25);
  });

  it("anchors at local midnight so a TBD game sorts first in its day", () => {
    // Read inside the zone: a Date holds an instant, so its clock fields
    // are whatever zone you ask in — which is the same trap the rule fixes.
    const [hours, minutes] = inZone("America/Los_Angeles", () => {
      const anchored = placeholderKickoff(new Date(SENTINEL));
      return [anchored.getHours(), anchored.getMinutes()];
    });
    expect(hours).toBe(0);
    expect(minutes).toBe(0);
  });

  it("leaves an announced kickoff untouched", () => {
    // Only the sentinel is re-anchored — a real 3:30 PM ET kickoff is a
    // real instant and must survive verbatim.
    const real = "2026-09-26T19:30:00Z";
    expect(parseKickoff(real, false)).toBe(real);
  });

  it("re-anchors only when the payload flags the time invalid", () => {
    expect(parseKickoff(SENTINEL, false)).toBe(SENTINEL);
    expect(parseKickoff(SENTINEL, true)).not.toBe(SENTINEL);
  });

  it("degrades rather than throwing on an unparseable date", () => {
    expect(parseKickoff("not a date", true)).toBe("not a date");
    expect(parseKickoff(undefined, true)).toBe("");
  });
});
