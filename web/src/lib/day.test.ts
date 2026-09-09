import { describe, expect, it } from "vitest";
import {
  addDays,
  clampDay,
  dayChipLabel,
  dayFromId,
  dayId,
  daysBetween,
  daysInRange,
  isSameDay,
  startOfDay,
} from "./day";

describe("day ids", () => {
  it("round-trips a local day", () => {
    const day = new Date(2026, 8, 5);
    expect(dayId(day)).toBe("2026-09-05");
    expect(dayFromId("2026-09-05")).toEqual(day);
  });

  it("pads every part", () => {
    expect(dayId(new Date(2026, 0, 3))).toBe("2026-01-03");
  });

  it("rejects a day that isn't one rather than rolling it over", () => {
    // `new Date(2026, 12, 1)` is next January and February 31st is March
    // 3rd — a link that lands the strip on a day nobody meant is worse than
    // one carrying no day at all.
    expect(dayFromId("2026-13-01")).toBeUndefined();
    expect(dayFromId("2026-02-31")).toBeUndefined();
    expect(dayFromId("nonsense")).toBeUndefined();
    expect(dayFromId("2026-9-5")).toBeUndefined();
  });
});

describe("day arithmetic", () => {
  it("counts whole calendar days", () => {
    expect(daysBetween(new Date(2026, 8, 5), new Date(2026, 8, 8))).toBe(3);
    expect(daysBetween(new Date(2026, 8, 8), new Date(2026, 8, 5))).toBe(-3);
  });

  it("survives a DST shift", () => {
    // US DST ends Nov 1 2026: that "day" is 25 hours long, so flooring the
    // millisecond difference would report 0 days between consecutive dates.
    const before = new Date(2026, 10, 1);
    const after = new Date(2026, 10, 2);
    expect(daysBetween(before, after)).toBe(1);
    expect(dayId(addDays(before, 1))).toBe("2026-11-02");
  });

  it("enumerates an inclusive range", () => {
    const days = daysInRange(new Date(2026, 8, 5), new Date(2026, 8, 8));
    expect(days.map(dayId)).toEqual([
      "2026-09-05",
      "2026-09-06",
      "2026-09-07",
      "2026-09-08",
    ]);
  });

  it("clamps into a span", () => {
    const [start, end] = [new Date(2026, 7, 1), new Date(2027, 1, 28)];
    expect(dayId(clampDay(new Date(2026, 0, 1), start, end))).toBe("2026-08-01");
    expect(dayId(clampDay(new Date(2028, 0, 1), start, end))).toBe("2027-02-28");
    expect(dayId(clampDay(new Date(2026, 8, 5), start, end))).toBe("2026-09-05");
  });

  it("compares days, not instants", () => {
    expect(
      isSameDay(new Date(2026, 8, 5, 1), new Date(2026, 8, 5, 23))
    ).toBe(true);
    expect(startOfDay(new Date(2026, 8, 5, 23)).getHours()).toBe(0);
  });
});

describe("day chip labels", () => {
  const today = new Date(2026, 8, 5);

  it("names yesterday and tomorrow beside today", () => {
    // "Yesterday" is what anyone calls yesterday, and VoiceOver was
    // already saying all three (iOS, 2026-09-06).
    expect(dayChipLabel(today, today)).toBe("Today");
    expect(dayChipLabel(addDays(today, -1), today)).toBe("Yesterday");
    expect(dayChipLabel(addDays(today, 1), today)).toBe("Tomorrow");
  });

  it("carries the month on every other chip", () => {
    // The strip spans a season that crosses a year boundary, so a bare
    // "Sat 5" stops meaning anything past the fortnight either side.
    expect(dayChipLabel(new Date(2026, 8, 27), today)).toBe("Sun, Sep 27");
    expect(dayChipLabel(new Date(2027, 0, 11), today)).toBe("Mon, Jan 11");
  });
});
