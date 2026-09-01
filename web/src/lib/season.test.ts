import { describe, it, expect } from "vitest";
import {
  cfbSeasonYear,
  seasonYears,
  makeWeekSlot,
  weekSlotContains,
  defaultWeekSelection,
} from "./season";

describe("cfbSeasonYear", () => {
  it("keeps September in the same season", () => {
    expect(cfbSeasonYear(new Date(2026, 8, 1))).toBe(2026);
  });

  it("puts January in the previous season (bowls/CFP)", () => {
    expect(cfbSeasonYear(new Date(2027, 0, 15))).toBe(2026);
  });

  it("flips to the upcoming season in February", () => {
    expect(cfbSeasonYear(new Date(2027, 1, 2))).toBe(2027);
  });
});

describe("seasonYears", () => {
  it("runs current → 2014 descending", () => {
    const years = seasonYears(new Date(2026, 8, 1));
    expect(years[0]).toBe(2026);
    expect(years[years.length - 1]).toBe(2014);
    expect(years).toHaveLength(13);
  });
});

// Synthetic slots mirroring ESPN's 2026 calendar shape. Week ranges are
// generous (multi-day) so local-vs-UTC parsing can't flip a test.
const week1 = makeWeekSlot({
  label: "Week 1",
  shortLabel: "Wk 1",
  seasonType: 2,
  value: 1,
  startDate: "2026-08-22T07:00Z",
  endDate: "2026-09-08T06:59Z",
});
const week2 = makeWeekSlot({
  label: "Week 2",
  shortLabel: "Wk 2",
  seasonType: 2,
  value: 2,
  startDate: "2026-09-08T07:00Z",
  endDate: "2026-09-15T06:59Z",
});
const bowls = makeWeekSlot({
  label: "Bowls",
  shortLabel: "Bowls",
  seasonType: 3,
  value: 1,
  startDate: "2026-12-13T08:00Z",
  endDate: "2027-01-28T07:59Z",
});
const cfp = makeWeekSlot({
  label: "CFP",
  shortLabel: "CFP",
  seasonType: 3,
  value: 999,
  startDate: "2026-12-18T08:00Z",
  endDate: "2027-01-28T07:59Z",
});
const slots = [week1, week2, bowls, cfp];

describe("weekSlotContains", () => {
  it("is a half-open range", () => {
    expect(weekSlotContains(week1, new Date("2026-08-25T12:00Z"))).toBe(true);
    expect(weekSlotContains(week1, new Date("2026-09-08T07:30Z"))).toBe(false);
  });

  it("never contains anything without both dates", () => {
    const dateless = makeWeekSlot({
      label: "X",
      shortLabel: "X",
      seasonType: 2,
      value: 9,
    });
    expect(weekSlotContains(dateless, new Date())).toBe(false);
  });
});

describe("defaultWeekSelection", () => {
  it("uses ESPN's current week on a weekday", () => {
    // Wednesday Sep 9, ESPN says week 2.
    const wednesday = new Date(2026, 8, 9, 12);
    expect(defaultWeekSelection(slots, 2, 2, wednesday)).toBe(week2);
  });

  it("pins Sunday to the slot containing yesterday, not ESPN's flipped-forward week", () => {
    // Sunday Sep 6: Saturday Sep 5 sits in week 1; ESPN has already
    // flipped its current week forward to week 2 (which does not contain
    // yesterday).
    const sunday = new Date(2026, 8, 6, 12);
    expect(sunday.getDay()).toBe(0);
    expect(defaultWeekSelection(slots, 2, 2, sunday)).toBe(week1);
  });

  it("breaks a Sunday overlap tie with ESPN's current slot", () => {
    // Sunday Dec 27: Saturday Dec 26 sits inside BOTH Bowls and CFP.
    // ESPN's current slot (CFP) qualifies, so it wins over first-containing.
    const playoffSunday = new Date(2026, 11, 27, 12);
    expect(playoffSunday.getDay()).toBe(0);
    expect(defaultWeekSelection(slots, 999, 3, playoffSunday)).toBe(cfp);
  });

  it("falls to first-containing on a Sunday overlap when ESPN's current does not qualify", () => {
    const playoffSunday = new Date(2026, 11, 27, 12);
    expect(defaultWeekSelection(slots, undefined, undefined, playoffSunday)).toBe(
      bowls
    );
  });

  it("selects the first slot before the season starts", () => {
    const july = new Date(2026, 6, 1, 12);
    expect(defaultWeekSelection(slots, undefined, undefined, july)).toBe(week1);
  });

  it("selects the last slot after the season ends", () => {
    const february = new Date(2027, 1, 10, 12);
    expect(defaultWeekSelection(slots, undefined, undefined, february)).toBe(
      cfp
    );
  });

  it("returns undefined for an empty strip", () => {
    expect(defaultWeekSelection([], 1, 2, new Date())).toBeUndefined();
  });
});
