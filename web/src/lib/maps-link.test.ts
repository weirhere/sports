// iOS `MapsLinkTests`, assertion for assertion.

import { describe, it, expect } from "vitest";
import { mapsLink } from "./maps-link";

describe("the venue's maps link", () => {
  it("joins name and city into one search", () => {
    expect(mapsLink("Benchmark International Arena", "Tampa, FL")).toBe(
      "https://maps.apple.com/?q=Benchmark%20International%20Arena,%20Tampa,%20FL"
    );
  });

  it("is the name alone without a city", () => {
    expect(mapsLink("Sanford Stadium")).toBe("https://maps.apple.com/?q=Sanford%20Stadium");
    expect(mapsLink("Sanford Stadium", "  ")).toBe(
      "https://maps.apple.com/?q=Sanford%20Stadium"
    );
  });

  it("keeps an ampersand inside the search", () => {
    const url = new URL(mapsLink("AT&T Stadium", "Arlington, TX")!);
    expect(url.searchParams.get("q")).toBe("AT&T Stadium, Arlington, TX");
  });

  it("is nothing without a name", () => {
    expect(mapsLink("", "Tampa, FL")).toBeUndefined();
    expect(mapsLink("   ")).toBeUndefined();
  });
});
