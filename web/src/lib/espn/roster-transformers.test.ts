// The roster mapper, against the two shapes ESPN actually ships.
//
// Fixtures are trimmed from live responses (2026-09-11): college football
// (team 333) and the NHL group their athletes, the NBA (team 13) does not.

import { describe, it, expect } from "vitest";
import { transformRoster } from "./transformers";
import type { EspnRosterResponse } from "./types";

const groupedResponse: EspnRosterResponse = {
  coach: [{ firstName: "Kalen", lastName: "DeBoer" }],
  athletes: [
    {
      position: "offense",
      items: [
        {
          id: "5269389",
          displayName: "Chris Booker",
          fullName: "Chris Booker",
          jersey: "73",
          displayHeight: "6' 4\"",
          displayWeight: "288 lbs",
          position: {
            name: "Offensive Lineman",
            displayName: "Offensive Lineman",
            abbreviation: "OL",
          },
          experience: { years: 1, displayValue: "Freshman", abbreviation: "FR" },
          headshot: {
            href: "https://a.espncdn.com/i/headshots/college-football/players/full/5269389.png",
          },
        },
      ],
    },
    { position: "specialTeam", items: [] },
    { position: "injuredReserveOrOut", items: [{ id: "2", displayName: "Hurt Guy" }] },
  ],
};

const flatResponse: EspnRosterResponse = {
  coach: [{ firstName: "JJ", lastName: "Redick" }],
  athletes: [
    {
      id: "5113969",
      displayName: "Cameron Carr",
      displayHeight: "6' 5\"",
      displayWeight: "184 lbs",
      age: 21,
      position: { name: "Guard", displayName: "Guard", abbreviation: "G" },
      experience: { years: 0 },
    },
    { id: "3945274", displayName: "Luka Doncic", jersey: "77", age: 27 },
  ],
};

describe("transformRoster — grouped payloads", () => {
  it("keeps ESPN's own groups, named for display", () => {
    const roster = transformRoster(groupedResponse);
    expect(roster.groups.map((group) => group.name)).toEqual([
      "Offense",
      "Injured reserve",
    ]);
  });

  it("drops an empty group rather than heading a card over nothing", () => {
    const roster = transformRoster(groupedResponse);
    expect(roster.groups.some((group) => group.name === "Special teams")).toBe(
      false
    );
  });

  it("maps a player's facts, and the class year college keeps instead of age", () => {
    const player = transformRoster(groupedResponse).groups[0].players[0];
    expect(player).toMatchObject({
      id: "5269389",
      name: "Chris Booker",
      jersey: "73",
      position: "OL",
      positionName: "Offensive Lineman",
      height: "6' 4\"",
      weight: "288 lbs",
      classAbbreviation: "FR",
    });
    expect(player.age).toBeUndefined();
  });

  it("reads the head coach", () => {
    expect(transformRoster(groupedResponse).coach).toEqual({
      name: "Kalen DeBoer",
    });
  });

  it("passes an unrecognized group code through capitalized", () => {
    const roster = transformRoster({
      athletes: [{ position: "taxiSquad", items: [{ id: "1", displayName: "A" }] }],
    });
    expect(roster.groups[0].name).toBe("TaxiSquad");
  });
});

describe("transformRoster — the NBA's flat payload", () => {
  it("collects loose athletes into one roster, not a group each", () => {
    const roster = transformRoster(flatResponse);
    expect(roster.groups).toHaveLength(1);
    expect(roster.groups[0].name).toBe("Roster");
    expect(roster.groups[0].players).toHaveLength(2);
  });

  it("keeps the age the pro leagues publish, and no class year", () => {
    // By name, not by index: the group is in jersey order, and Carr has no
    // number, so he sits behind Doncic.
    const player = transformRoster(flatResponse).groups[0].players.find(
      (candidate) => candidate.name === "Cameron Carr"
    )!;
    expect(player.age).toBe(21);
    // `experience: { years: 0 }` is seasons played, not a class — reading it
    // as one would put "0" under a CLASS caption.
    expect(player.classAbbreviation).toBeUndefined();
  });
});

describe("transformRoster — jersey order", () => {
  // ESPN sorts a group alphabetically by last name; the card sorts it by the
  // number it prints. Numeric, not lexical: a string sort files 7 behind 14.
  const numbered = (jerseys: (string | undefined)[]): EspnRosterResponse => ({
    athletes: [
      {
        position: "offense",
        items: jerseys.map((jersey, index) => ({
          id: String(index),
          displayName: `Player ${index}`,
          jersey,
        })),
      },
    ],
  });

  it("sorts a group by number, not by string", () => {
    const roster = transformRoster(numbered(["14", "7", "70", "3"]));
    expect(roster.groups[0].players.map((player) => player.jersey)).toEqual([
      "3",
      "7",
      "14",
      "70",
    ]);
  });

  it("leaves the numberless at the end, in the order ESPN shipped them", () => {
    const roster = transformRoster(numbered([undefined, "12", undefined, "4"]));
    expect(roster.groups[0].players.map((player) => player.name)).toEqual([
      "Player 3",
      "Player 1",
      "Player 0",
      "Player 2",
    ]);
  });

  // College football runs duplicate numbers on purpose, and an unreadable
  // jersey is no number at all — both keep the order they arrived in.
  it("keeps ties and unreadable numbers stable", () => {
    const roster = transformRoster(numbered(["9B", "4", "4", "00"]));
    expect(roster.groups[0].players.map((player) => player.name)).toEqual([
      "Player 3",
      "Player 1",
      "Player 2",
      "Player 0",
    ]);
  });
});

describe("transformRoster — degradation", () => {
  it("drops a player with no name or no id, never the roster", () => {
    const roster = transformRoster({
      athletes: [
        {
          position: "defense",
          items: [
            { id: "1", displayName: "Real Player" },
            { displayName: "No Id" },
            { id: "3" },
          ],
        },
      ],
    });
    expect(roster.groups[0].players.map((player) => player.name)).toEqual([
      "Real Player",
    ]);
  });

  it("leads with the first injury designation ESPN lists", () => {
    const roster = transformRoster({
      athletes: [
        {
          id: "1",
          displayName: "Banged Up",
          injuries: [{ status: "Questionable" }, { status: "Out" }],
        },
      ],
    });
    expect(roster.groups[0].players[0].injuryStatus).toBe("Questionable");
  });

  it("is empty — not a throw — for a response carrying nothing", () => {
    expect(transformRoster({})).toEqual({ coach: undefined, groups: [] });
  });

  it("omits a coach with no name rather than an empty row", () => {
    expect(transformRoster({ coach: [{}] }).coach).toBeUndefined();
  });
});
