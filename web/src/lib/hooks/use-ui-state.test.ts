import { describe, expect, it } from "vitest";
import { sanitize, toStored } from "./use-ui-state";

// Live and Tight are session-only (2026-10-22): the funnel filter and Hide
// all survive a reload, the two "now" filters start off every time.
describe("use-ui-state persistence", () => {
  it("ignores a Live or Tight an older build saved", () => {
    const state = sanitize({
      liveOnly: true,
      tightOnly: true,
      scoreFilter: "top25",
      hideOtherSections: true,
    });
    expect(state.liveOnly).toBe(false);
    expect(state.tightOnly).toBe(false);
    expect(state.scoreFilter).toBe("top25");
    expect(state.hideOtherSections).toBe(true);
  });

  it("never writes Live or Tight", () => {
    const stored = toStored({
      ...sanitize(null),
      liveOnly: true,
      tightOnly: false,
      scoreFilter: "top25",
    });
    expect(stored).not.toHaveProperty("liveOnly");
    expect(stored).not.toHaveProperty("tightOnly");
    expect(stored.scoreFilter).toBe("top25");
  });
});
