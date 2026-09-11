import { describe, expect, it } from "vitest";
import type { ConferenceStandingsGroup, Team, TeamScheduleData } from "@/lib/types";
import { conferenceCardModel, teamCardModel } from "./entity";

function team(overrides: Partial<Team> = {}): Team {
  return {
    id: "194",
    espnId: 194,
    league: "cfb",
    name: "Buckeyes",
    school: "Ohio State",
    abbreviation: "OSU",
    conferenceId: "5",
    conferenceName: "Big Ten",
    division: "FBS",
    logoUrl: "https://a.espncdn.com/i/teamlogos/ncaa/500/194.png",
    ...overrides,
  };
}

function schedule(overrides: Partial<TeamScheduleData> = {}): TeamScheduleData {
  return { team: team(), record: "7-1", games: [], ...overrides };
}

function table(entryCount: number, id = "5"): ConferenceStandingsGroup {
  return {
    id,
    league: "cfb",
    name: "Big Ten",
    entries: Array.from({ length: entryCount }, (_, i) => ({
      team: team({ id: String(i), school: `Team ${i}` }),
      overallRecord: "1-0",
    })) as ConferenceStandingsGroup["entries"],
  };
}

describe("a team's card", () => {
  it("leads with the league, then the school and its season", () => {
    const card = teamCardModel("cfb", schedule());
    expect(card.kicker).toBe("COLLEGE FOOTBALL");
    expect(card.title).toBe("Ohio State");
    expect(card.subtitle).toBe("Big Ten · 7-1");
  });

  it("hides a record nobody has played yet", () => {
    // The preseason gate the app applies to a standing line: a 0-0 team
    // says nothing about its season rather than claiming a blank one.
    expect(teamCardModel("cfb", schedule({ record: "0-0" })).subtitle).toBe(
      "Big Ten"
    );
  });

  it("falls back to the derived record a past season carries", () => {
    const card = teamCardModel(
      "cfb",
      schedule({ record: undefined, derivedRecord: "11-2" })
    );
    expect(card.subtitle).toBe("Big Ten · 11-2");
  });

  it("drops a conference the registry can't name", () => {
    // An FCS visitor, or an id that isn't in the registry at all: the
    // hero shows no conference line there either.
    const card = teamCardModel(
      "cfb",
      schedule({ team: team({ conferenceId: "999999" }) })
    );
    expect(card.subtitle).toBe("7-1");
  });

  it("says nothing at all when there is nothing to say", () => {
    const card = teamCardModel(
      "cfb",
      schedule({ team: team({ conferenceId: "999999" }), record: "0-0" })
    );
    expect(card.subtitle).toBeUndefined();
  });

  it("describes the team without a number that would freeze in a cache", () => {
    const card = teamCardModel("cfb", schedule());
    expect(card.description).toBe(
      "Every Ohio State game: schedule, live scores and standings."
    );
    expect(card.description).not.toMatch(/\d/);
  });
});

describe("a conference's card", () => {
  it("counts every team, across divisions", () => {
    // The hero's own rule: the count sums each division, however the
    // tables are sliced.
    const card = conferenceCardModel("cfb", "Sun Belt", undefined, [
      table(7, "5-east"),
      table(7, "5-west"),
    ]);
    expect(card.title).toBe("Sun Belt");
    expect(card.subtitle).toBe("14 teams");
  });

  it("drops the count when the standings fetch failed", () => {
    // One line is not worth a card: the mark and the name still stand.
    expect(conferenceCardModel("nfl", "AFC", undefined, null).subtitle).toBe(
      undefined
    );
  });
});

describe("a league's own table", () => {
  it("doesn't say NFL over NFL over the NFL shield", () => {
    const card = conferenceCardModel("nfl", "NFL", undefined, null);
    expect(card.kicker).toBeUndefined();
    expect(card.title).toBe("NFL");
  });

  it("keeps the kicker where it adds something", () => {
    // "FBS" inside college football is a division, not a synonym.
    expect(conferenceCardModel("cfb", "FBS", undefined, null).kicker).toBe(
      "COLLEGE FOOTBALL"
    );
  });
});
