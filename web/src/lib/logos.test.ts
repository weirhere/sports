import { describe, it, expect } from "vitest";
import { darkTeamLogoVariant } from "./logos";

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
