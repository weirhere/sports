import { describe, expect, it } from "vitest";
import { SLATE_FOCUSES, slateFocus, slateFocusDescription, slateFocusTitle } from "./slate-focus";

describe("the Scores focus menu (2026-10-19)", () => {
  it("reads the two filters as one choice", () => {
    expect(slateFocus(false, false)).toBe("all");
    expect(slateFocus(true, false)).toBe("live");
    expect(slateFocus(false, true)).toBe("tight");
    // The stores keep the two exclusive; were both ever on, Live wins, as
    // `useUiState` reads them.
    expect(slateFocus(true, true)).toBe("live");
  });

  it("names the three rows, and explains only Tight", () => {
    expect(SLATE_FOCUSES.map(slateFocusTitle)).toEqual(["All games", "Live", "Tight"]);
    expect(SLATE_FOCUSES.map(slateFocusDescription)).toEqual([
      undefined,
      undefined,
      "Live and close, late in the game, or an upset brewing",
    ]);
  });
});
