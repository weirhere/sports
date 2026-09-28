// The coach page's rules, pinned against the same live captures (2026-09-27)
// as iOS `CoachTests`, so the two platforms can't drift apart quietly.

import { describe, expect, it } from "vitest";
import person from "./espn/__fixtures__/nfl-coach.json";
import totalJson from "./espn/__fixtures__/nfl-coach-record-total.json";
import postJson from "./espn/__fixtures__/nfl-coach-record-post.json";
import seasonJson from "./espn/__fixtures__/nfl-coach-season.json";
import {
  careerRecords,
  cleanedSeasons,
  coachAge,
  coachInitials,
  coachProfile,
  coachRecord,
  coachSeasons,
  coachStints,
  recordSummary,
  seasonId,
  seasonYearInRef,
  stintRecord,
  stintSpan,
  winPercentText,
  type CoachRecord,
  type CoachRecordKind,
  type EspnCoachPerson,
  type EspnCoachRecord,
} from "./coach";

function record(w: number, l: number, opts: { t?: number; otl?: number; kind?: CoachRecordKind } = {}): CoachRecord {
  return { kind: opts.kind ?? "regular", wins: w, losses: l, ties: opts.t ?? 0, overtimeLosses: opts.otl ?? 0 };
}

describe("coach mapping", () => {
  it("reads the bio off the person record", () => {
    const profile = coachProfile(person as EspnCoachPerson);
    expect(profile.name).toBe("Todd Bowles");
    expect(profile.birthPlace).toBe("Elizabeth, New Jersey");
    expect(profile.dateOfBirth).toBe("1963-11-18");
    expect(profile.currentTeamId).toBe("27");
    expect(profile.headshotUrl).toBe("https://a.espncdn.com/i/headshots/nfl/coaches/65/7157.jpg");
    expect(coachAge(profile.dateOfBirth, new Date("2026-09-27T12:00:00Z"))).toBe(62);
    expect(coachAge(profile.dateOfBirth, new Date("2026-11-18T12:00:00Z"))).toBe(63);
  });

  it("names every season's year from its ref, with the gap left out", () => {
    const years = ((person as EspnCoachPerson).coachSeasons ?? []).map((r) => seasonYearInRef(r.$ref));
    expect(years).toContain(2015);
    expect(years).toContain(2026);
    expect(years).not.toContain(2019);
  });

  it("reads a career record's kind and counts", () => {
    const total = coachRecord(totalJson as EspnCoachRecord, "nfl");
    expect(total?.kind).toBe("total");
    expect(total && recordSummary(total)).toBe("60-77");
    const post = coachRecord(postJson as EspnCoachRecord, "nfl");
    expect(post?.kind).toBe("postseason");
    expect(post && winPercentText(post)).toBe(".250");
  });

  it("puts a season on our year axis with its team", () => {
    const rows = coachSeasons(seasonJson, 2016, record(5, 11), "nfl");
    expect(rows).toEqual([{ year: 2016, teamId: "20", record: record(5, 11) }]);
    expect(coachSeasons(seasonJson, 2026, undefined, "nba")[0].year).toBe(2025);
  });

  it("counts overtime losses only in hockey, in all three spellings", () => {
    const dto: EspnCoachRecord = {
      id: "0",
      name: "Total",
      stats: [
        { name: "wins", value: 1072 },
        { name: "losses", value: 671 },
        { name: "ties", value: 77 },
        { name: "OTLosses", value: 159 },
      ],
    };
    expect(recordSummary(coachRecord(dto, "nhl")!)).toBe("1072-671-77-159");
    expect(recordSummary(coachRecord(dto, "nfl")!)).toBe("1072-671-77");
    const tocchet: EspnCoachRecord = {
      name: "Regular Season",
      stats: [
        { name: "otLosses", value: 8 },
        { name: "losses", value: 29 },
        { name: "wins", value: 33 },
        { name: "overtimeLosses", value: 8 },
      ],
    };
    expect(recordSummary(coachRecord(tocchet, "nhl")!)).toBe("33-29-8");
  });

  it("gives up on a record with no wins or losses", () => {
    expect(coachRecord({ name: "Total", stats: [{ name: "ties", value: 0 }] }, "nfl")).toBeUndefined();
  });
});

describe("coach career shape", () => {
  it("drops a regular line that only repeats the total (college football)", () => {
    const lines = careerRecords([record(60, 16), record(60, 16, { kind: "total" })]);
    expect(lines.map((r) => r.kind)).toEqual(["total"]);
  });

  it("keeps all three pro lines in order", () => {
    const lines = careerRecords([
      record(1, 3, { kind: "postseason" }),
      record(59, 74),
      record(60, 77, { kind: "total" }),
    ]);
    expect(lines.map((r) => r.kind)).toEqual(["total", "regular", "postseason"]);
  });

  it("drops zero-game lines", () => {
    expect(careerRecords([record(0, 0, { kind: "total" })])).toEqual([]);
    expect(winPercentText(record(0, 0))).toBeUndefined();
  });

  it("drops the season a coach left, and ESPN's duplicates", () => {
    const rows = cleanedSeasons([
      { year: 2023, teamId: "264", record: record(14, 1) },
      { year: 2024, teamId: "264", record: record(0, 0) },
      { year: 2025, teamId: "333", record: record(11, 3) },
      { year: 2024, teamId: "264", record: record(0, 0) },
      { year: 2026, teamId: "333" },
      { year: 2025, teamId: "333", record: record(11, 3) },
    ]);
    expect(rows.map(seasonId)).toEqual(["2026-333", "2025-333", "2023-264"]);
  });

  it("groups seasons into stints, and a gap splits one", () => {
    const stints = coachStints([
      { year: 2026, teamId: "27" },
      { year: 2025, teamId: "27", record: record(8, 9) },
      { year: 2022, teamId: "27", record: record(8, 9) },
      { year: 2016, teamId: "20", record: record(5, 11) },
      { year: 2015, teamId: "20", record: record(10, 6) },
    ]);
    expect(stints.map((s) => s.teamId)).toEqual(["27", "27", "20"]);
    expect(stintSpan(stints[0], "nfl")).toBe("2025–2026");
    expect(stintSpan(stints[1], "nfl")).toBe("2022");
    expect(stintSpan(stints[2], "nfl")).toBe("2015–2016");
    expect(recordSummary(stintRecord(stints[2])!)).toBe("15-17");
    expect(stintSpan({ teamId: "13", seasons: [{ year: 2025, teamId: "13" }, { year: 2024, teamId: "13" }] }, "nba"))
      .toBe("2024-25–2025-26");
  });

  it("counts a tie as half a win", () => {
    expect(winPercentText(record(8, 8, { t: 1 }))).toBe(".500");
    expect(recordSummary(record(8, 8, { t: 1 }))).toBe("8-8-1");
  });

  it("makes initials from the first and last names", () => {
    expect(coachInitials("Todd Bowles")).toBe("TB");
    expect(coachInitials("Chris Godwin Jr.")).toBe("CG");
    expect(coachInitials("Kalen DeBoer")).toBe("KD");
  });
});
