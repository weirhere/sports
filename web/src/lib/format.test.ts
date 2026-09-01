import { describe, it, expect } from "vitest";
import { periodLabel, liveStatusText } from "./format";

describe("periodLabel", () => {
  it("labels regulation quarters", () => {
    expect(periodLabel(1)).toBe("Q1");
    expect(periodLabel(4)).toBe("Q4");
  });

  it("labels overtimes", () => {
    expect(periodLabel(5)).toBe("OT");
    expect(periodLabel(6)).toBe("2OT");
    expect(periodLabel(7)).toBe("3OT");
  });
});

describe("liveStatusText", () => {
  it("says Half at halftime — never Q2 0:00", () => {
    expect(
      liveStatusText({ livePhase: "halftime", quarter: 2, clock: "0:00" })
    ).toBe("Half");
  });

  it("says End Q{n} at end of period — the clock has run out", () => {
    expect(
      liveStatusText({ livePhase: "endOfPeriod", quarter: 1, clock: "0:00" })
    ).toBe("End Q1");
  });

  it("joins period and clock while playing", () => {
    expect(
      liveStatusText({ livePhase: "playing", quarter: 3, clock: "5:24" })
    ).toBe("Q3 5:24");
  });

  it("labels overtime", () => {
    expect(
      liveStatusText({ livePhase: "playing", quarter: 5, clock: "0:48" })
    ).toBe("OT 0:48");
  });

  it("defaults the phase to playing", () => {
    expect(liveStatusText({ quarter: 2, clock: "10:11" })).toBe("Q2 10:11");
  });

  it("degrades to ESPN's detail when parts are missing", () => {
    expect(liveStatusText({ livePhase: "playing", detail: "In Progress" })).toBe(
      "In Progress"
    );
    expect(
      liveStatusText({ livePhase: "endOfPeriod", detail: "End of 1st" })
    ).toBe("End of 1st");
  });

  it("returns undefined with nothing to say", () => {
    expect(liveStatusText({})).toBeUndefined();
  });
});
