// The loader that has silently failed twice.
//
// Both failures rendered a *valid* card — Satori falls back to its own
// one-weight font, and the loader's whole contract is that a plain card
// beats no card — so nothing threw, nothing logged, and the only symptom
// was type that looked slightly wrong in a PNG nobody diffs. These
// assertions are the thing that was missing: not "did it return", but
// "are these three different real typefaces".

import { describe, expect, it } from "vitest";
import { interFonts } from "./fonts";

/** WOFF's magic number: the four bytes `wOFF` open every valid file. */
const WOFF_SIGNATURE = "wOFF";

describe("interFonts", () => {
  it("loads all three weights", async () => {
    const fonts = await interFonts();
    expect(fonts).toBeDefined();
    expect(fonts?.map((f) => f.weight)).toEqual([400, 600, 700]);
  });

  it("reads real typefaces, not whatever else is in the folder", async () => {
    // The folder also holds LICENSE.txt, which an interpolated asset path
    // once handed back in place of a font: "Unsupported OpenType signature
    // Copy" — the opening of "Copyright (c) 2016 The Inter Project".
    const fonts = await interFonts();
    for (const font of fonts ?? []) {
      const head = Buffer.from(font.data).subarray(0, 4).toString("latin1");
      expect(head).toBe(WOFF_SIGNATURE);
    }
  });

  it("reads a different file for each weight", async () => {
    // The failure this catches renders a card with no weight hierarchy at
    // all — which, on a card whose hierarchy is *only* weight and size, is
    // the whole design gone.
    const fonts = await interFonts();
    const bytes = (fonts ?? []).map((f) =>
      Buffer.from(f.data).toString("base64")
    );
    expect(new Set(bytes).size).toBe(3);
  });
});
