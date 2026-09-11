import { describe, it, expect } from "vitest";
import { darkTeamLogoVariant, headshotThumbnail } from "./logos";

describe("darkTeamLogoVariant", () => {
  it("rewrites team logos to the 500-dark variant", () => {
    expect(
      darkTeamLogoVariant("https://a.espncdn.com/i/teamlogos/ncaa/500/333.png")
    ).toBe("https://a.espncdn.com/i/teamlogos/ncaa/500-dark/333.png");
  });

  it("returns null for conference marks — no verified dark twin", () => {
    expect(
      darkTeamLogoVariant(
        "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/sec.png"
      )
    ).toBeNull();
  });

  it("returns null for GUID-style logo URLs", () => {
    expect(
      darkTeamLogoVariant(
        "https://a.espncdn.com/guid/2acff74d-269f-36ac-96eb-9c66f8ba52ff/logos/default.png"
      )
    ).toBeNull();
  });

  it("returns null for non-espncdn hosts", () => {
    expect(
      darkTeamLogoVariant("https://example.com/i/teamlogos/ncaa/500/333.png")
    ).toBeNull();
  });

  it("returns null for unparseable URLs", () => {
    expect(darkTeamLogoVariant("not a url")).toBeNull();
  });
});

describe("dark variants across leagues", () => {
  it("derives a dark twin in every team bucket", () => {
    // All four verified 200 against the CDN on 2026-09-09.
    expect(
      darkTeamLogoVariant("https://a.espncdn.com/i/teamlogos/nfl/500/ne.png")
    ).toBe("https://a.espncdn.com/i/teamlogos/nfl/500-dark/ne.png");
    expect(
      darkTeamLogoVariant("https://a.espncdn.com/i/teamlogos/nba/500/bos.png")
    ).toBe("https://a.espncdn.com/i/teamlogos/nba/500-dark/bos.png");
  });

  it("keeps the NHL's nested scoreboard path", () => {
    expect(
      darkTeamLogoVariant(
        "https://a.espncdn.com/i/teamlogos/nhl/500/scoreboard/sea.png"
      )
    ).toBe("https://a.espncdn.com/i/teamlogos/nhl/500-dark/scoreboard/sea.png");
  });

  it("still refuses conference marks", () => {
    // `ncaa_conf/500/` shares the `/500/` shape but has no dark twin under
    // any spelling — a header rides a light backing disc instead.
    expect(
      darkTeamLogoVariant(
        "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/sec.png"
      )
    ).toBeNull();
  });
});

describe("headshotThumbnail", () => {
  it("asks the CDN's combiner for a row-sized photo", () => {
    expect(
      headshotThumbnail(
        "https://a.espncdn.com/i/headshots/college-football/players/full/5269389.png"
      )
    ).toBe(
      "https://a.espncdn.com/combiner/i?img=/i/headshots/college-football/players/full/5269389.png&w=150&h=110"
    );
  });

  it("covers every league's headshot bucket", () => {
    for (const bucket of ["nfl", "nba", "nhl"]) {
      expect(
        headshotThumbnail(
          `https://a.espncdn.com/i/headshots/${bucket}/players/full/3139477.png`
        )
      ).toContain(`img=/i/headshots/${bucket}/players/full/3139477.png`);
    }
  });

  it("returns null for a team logo, so only headshots get resized", () => {
    expect(
      headshotThumbnail("https://a.espncdn.com/i/teamlogos/ncaa/500/333.png")
    ).toBeNull();
  });

  it("returns null for non-espncdn hosts and unparseable URLs", () => {
    expect(
      headshotThumbnail("https://example.com/i/headshots/nfl/players/full/1.png")
    ).toBeNull();
    expect(headshotThumbnail("not a url")).toBeNull();
  });
});
