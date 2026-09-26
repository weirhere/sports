import { describe, expect, it } from "vitest";
import { teamFullName, teamSpokenLabel, teamSubtitle } from "./team-name";
import type { Team } from "./types";

function team(fields: Partial<Team> & Pick<Team, "league" | "id">): Team {
  return {
    espnId: Number(fields.id),
    name: "",
    school: "",
    abbreviation: "",
    conferenceId: "0",
    conferenceName: "",
    logoUrl: "",
    ...fields,
  };
}

describe("teamFullName", () => {
  it("joins the location and the nickname", () => {
    expect(teamFullName({ school: "Ohio State", name: "Buckeyes" })).toBe(
      "Ohio State Buckeyes"
    );
  });

  it("is the location alone when ESPN sends no nickname", () => {
    expect(teamFullName({ school: "Mercyhurst", name: "" })).toBe("Mercyhurst");
  });
});

describe("teamSubtitle", () => {
  it("leads with the league, then the conference", () => {
    const osu = team({ league: "cfb", id: "194", school: "Ohio State", name: "Buckeyes", conferenceId: "5" });
    expect(teamSubtitle(osu)).toBe("NCAAF • Big Ten");
  });

  it("names an NFL team's division, not its conference", () => {
    // Dallas is filed under the NFC (7) by the directory.
    const dallas = team({ league: "nfl", id: "6", school: "Dallas", name: "Cowboys", conferenceId: "7" });
    expect(teamSubtitle(dallas)).toBe("NFL • NFC East");
  });

  it("falls back to the league alone rather than a trailing bullet", () => {
    const unknown = team({ league: "cfb", id: "999999", school: "Somewhere", name: "Owls", conferenceId: "0" });
    expect(teamSubtitle(unknown)).toBe("NCAAF");
  });
});

describe("teamSpokenLabel", () => {
  it("speaks the league as a phrase and drops the bullet", () => {
    const osu = team({ league: "cfb", id: "194", school: "Ohio State", name: "Buckeyes", conferenceId: "5" });
    expect(teamSpokenLabel(osu)).toBe("Ohio State Buckeyes, College Football Big Ten");
  });

  it("is the name and the league when there is no group", () => {
    const unknown = team({ league: "cfb", id: "999999", school: "Somewhere", name: "Owls" });
    expect(teamSpokenLabel(unknown)).toBe("Somewhere Owls, College Football");
  });
});
