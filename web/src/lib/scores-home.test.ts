import { describe, expect, it } from "vitest";
import { isScoresRetap } from "./scores-home";
import { narrowsOn } from "./hooks/use-ui-state";

// A Games re-tap (iOS, 2026-09-20/21) and the today-only "now" filters
// (iOS, 2026-09-12).

const click = {
  button: 0,
  metaKey: false,
  ctrlKey: false,
  shiftKey: false,
  altKey: false,
  defaultPrevented: false,
};

describe("isScoresRetap", () => {
  it("is the Games link clicked from Games", () => {
    expect(isScoresRetap("/", "/", click)).toBe(true);
  });

  it("is an ordinary navigation from anywhere else, or to anywhere else", () => {
    expect(isScoresRetap("/", "/rankings", click)).toBe(false);
    expect(isScoresRetap("/teams", "/", click)).toBe(false);
  });

  it("leaves a modified or secondary click to the browser", () => {
    expect(isScoresRetap("/", "/", { ...click, metaKey: true })).toBe(false);
    expect(isScoresRetap("/", "/", { ...click, ctrlKey: true })).toBe(false);
    expect(isScoresRetap("/", "/", { ...click, shiftKey: true })).toBe(false);
    expect(isScoresRetap("/", "/", { ...click, button: 1 })).toBe(false);
    expect(isScoresRetap("/", "/", { ...click, defaultPrevented: true })).toBe(
      false
    );
  });
});

describe("narrowsOn", () => {
  const now = new Date(2026, 8, 26, 21, 30);

  it("narrows today while the intent is on", () => {
    expect(narrowsOn(true, new Date(2026, 8, 26), now)).toBe(true);
  });

  it("is suspended on every other day, and remembers nothing itself", () => {
    expect(narrowsOn(true, new Date(2026, 8, 27), now)).toBe(false);
    expect(narrowsOn(true, new Date(2026, 8, 25), now)).toBe(false);
  });

  it("never narrows with the intent off", () => {
    expect(narrowsOn(false, new Date(2026, 8, 26), now)).toBe(false);
  });
});
