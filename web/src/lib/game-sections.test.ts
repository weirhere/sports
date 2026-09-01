import { describe, expect, it } from "vitest";
import type { Game, GameStatus, GameTeam, Team } from "./types";
import {
  buildSections,
  DAY_SECTION_PREFIX,
  FOLLOWING_SECTION_ID,
  TBD_SECTION_ID,
  TOP25_SECTION_ID,
  localDayKey,
  scoreFilterChipLabel,
  scoreFilterLabel,
} from "./game-sections";

function team(id: string, school: string, conferenceId: string): Team {
  return {
    id,
    espnId: Number(id),
    name: school,
    school,
    abbreviation: school.slice(0, 3).toUpperCase(),
    conferenceId,
    conferenceName: "",
    division: "FBS",
    logoUrl: "",
  };
}

function side(t: Team, ranking?: number): GameTeam {
  return { team: t, score: null, ranking };
}

let nextId = 1;
function game(fields: {
  home: GameTeam;
  away: GameTeam;
  scheduledAt?: string;
  status?: GameStatus;
  id?: string;
}): Game {
  return {
    id: fields.id ?? `g${nextId++}`,
    status: fields.status ?? "scheduled",
    scheduledAt: fields.scheduledAt ?? "2026-09-05T19:30:00Z",
    venue: { name: "", city: "", state: "" },
    homeTeam: fields.home,
    awayTeam: fields.away,
    week: 1,
    seasonYear: 2026,
    conferenceGame: false,
  };
}

// Registry ids: SEC 8, Big Ten 5, MAC 15, Sun Belt 37; "0" is unknown/FCS.
const georgia = team("61", "Georgia", "8");
const alabama = team("333", "Alabama", "8");
const michigan = team("130", "Michigan", "5");
const ohioState = team("194", "Ohio State", "5");
const toledo = team("2649", "Toledo", "15");
const troy = team("2653", "Troy", "37");
const fcsVisitor = team("2755", "Wofford", "0");

const noFollows = {
  followedTeamIds: [] as string[],
  followedConferenceIds: [] as number[],
};

describe("buildSections — conference grouping", () => {
  it("duplicates a cross-conference ranked game into Top 25 and both conferences, and Following when followed", () => {
    const g = game({ home: side(georgia, 3), away: side(michigan) });
    const sections = buildSections([g], {
      grouping: "conference",
      followedTeamIds: ["130"],
      followedConferenceIds: [],
    });

    const ids = sections.map((s) => s.id);
    expect(ids).toContain(FOLLOWING_SECTION_ID);
    expect(ids).toContain(TOP25_SECTION_ID);
    expect(ids).toContain("conf-SEC");
    expect(ids).toContain("conf-Big Ten");
    // The same game, never deduplicated, in all four sections.
    for (const section of sections) {
      expect(section.games.map((x) => x.id)).toContain(g.id);
    }
  });

  it("keeps an FCS visitor in its host's conference only — never in Other", () => {
    const g = game({ home: side(georgia), away: side(fcsVisitor) });
    const sections = buildSections([g], {
      grouping: "conference",
      ...noFollows,
    });
    expect(sections.map((s) => s.id)).toEqual(["conf-SEC"]);
  });

  it("buckets both-sides-unknown games into Other", () => {
    const g = game({
      home: side(team("9990", "Mystery A", "0")),
      away: side(fcsVisitor),
    });
    const sections = buildSections([g], {
      grouping: "conference",
      ...noFollows,
    });
    expect(sections.map((s) => s.id)).toEqual(["conf-Other"]);
    expect(sections[0].conferenceId).toBeUndefined();
  });

  it("floats followed conferences (and followed teams' conferences) above tier order", () => {
    const games = [
      game({ home: side(georgia), away: side(alabama) }),
      game({ home: side(michigan), away: side(ohioState) }),
      game({ home: side(toledo), away: side(troy) }),
    ];
    // Follow the MAC (id 15) and a Big Ten team: both float above SEC.
    const sections = buildSections(games, {
      grouping: "conference",
      followedTeamIds: ["130"],
      followedConferenceIds: [15],
    });
    const confIds = sections
      .filter((s) => s.kind === "conference")
      .map((s) => s.id);
    // Floated (tier order within: Big Ten P4, MAC G5), then the rest.
    expect(confIds).toEqual([
      "conf-Big Ten",
      "conf-MAC",
      "conf-SEC",
      "conf-Sun Belt",
    ]);
  });

  it("pins Following first and includes conference-followed games", () => {
    const secGame = game({ home: side(georgia), away: side(alabama) });
    const b1gGame = game({ home: side(michigan), away: side(ohioState) });
    const sections = buildSections([b1gGame, secGame], {
      grouping: "conference",
      followedTeamIds: [],
      followedConferenceIds: [8],
    });
    expect(sections[0].id).toBe(FOLLOWING_SECTION_ID);
    expect(sections[0].games.map((g) => g.id)).toEqual([secGame.id]);
  });
});

describe("buildSections — date grouping", () => {
  it("buckets by LOCAL calendar day, chronologically, with stable ids", () => {
    // 2026-09-05T03:30Z is the evening of Sep 4 in US timezones (and still
    // Sep 5 in UTC+ locales) — the assertion derives the expected local key
    // rather than hardcoding either.
    const lateKick = game({
      home: side(georgia),
      away: side(alabama),
      scheduledAt: "2026-09-05T03:30:00Z",
    });
    const dayKick = game({
      home: side(michigan),
      away: side(ohioState),
      scheduledAt: "2026-09-05T16:00:00Z",
    });
    const sections = buildSections([dayKick, lateKick], {
      grouping: "date",
      ...noFollows,
    });
    const lateKey = localDayKey(new Date(lateKick.scheduledAt));
    const dayKey = localDayKey(new Date(dayKick.scheduledAt));
    const expectedIds =
      lateKey === dayKey
        ? [`${DAY_SECTION_PREFIX}${dayKey}`]
        : [`${DAY_SECTION_PREFIX}${lateKey}`, `${DAY_SECTION_PREFIX}${dayKey}`];
    expect(sections.map((s) => s.id)).toEqual(expectedIds);
    // Chronological inside a section, whatever the input order.
    expect(sections[0].games[0].id).toBe(lateKick.id);
  });

  it("sends games without a parseable date to a trailing TBD section", () => {
    const dated = game({ home: side(georgia), away: side(alabama) });
    const undated = game({
      home: side(michigan),
      away: side(ohioState),
      scheduledAt: "not-a-date",
    });
    const sections = buildSections([undated, dated], {
      grouping: "date",
      ...noFollows,
    });
    expect(sections[sections.length - 1].id).toBe(TBD_SECTION_ID);
    expect(sections[sections.length - 1].games.map((g) => g.id)).toEqual([
      undated.id,
    ]);
  });

  it("pins Following first in date grouping too", () => {
    const g = game({ home: side(georgia), away: side(alabama) });
    const sections = buildSections([g], {
      grouping: "date",
      followedTeamIds: [georgia.id],
      followedConferenceIds: [],
    });
    expect(sections[0].id).toBe(FOLLOWING_SECTION_ID);
    expect(sections[1].id.startsWith(DAY_SECTION_PREFIX)).toBe(true);
  });
});

describe("buildSections — filters", () => {
  const liveSec = game({
    home: side(georgia),
    away: side(alabama),
    status: "in_progress",
  });
  const preSec = game({ home: side(georgia), away: side(fcsVisitor) });
  const liveB1g = game({
    home: side(michigan, 4),
    away: side(ohioState),
    status: "halftime",
  });

  it("liveOnly keeps only live games (halftime and end_period count)", () => {
    const sections = buildSections([liveSec, preSec, liveB1g], {
      grouping: "conference",
      ...noFollows,
      liveOnly: true,
    });
    const all = new Set(sections.flatMap((s) => s.games.map((g) => g.id)));
    expect(all).toEqual(new Set([liveSec.id, liveB1g.id]));
  });

  it("conference filter narrows every section, Following included, and composes with liveOnly", () => {
    const sections = buildSections([liveSec, preSec, liveB1g], {
      grouping: "conference",
      followedTeamIds: [georgia.id, michigan.id],
      followedConferenceIds: [],
      liveOnly: true,
      scoreFilter: "conference-8",
    });
    expect(sections.map((s) => s.id)).toEqual([
      FOLLOWING_SECTION_ID,
      "conf-SEC",
    ]);
    for (const section of sections) {
      expect(section.games.map((g) => g.id)).toEqual([liveSec.id]);
    }
  });

  it("top25 filter keeps any-ranked-participant games in both groupings", () => {
    for (const grouping of ["conference", "date"] as const) {
      const sections = buildSections([liveSec, preSec, liveB1g], {
        grouping,
        ...noFollows,
        scoreFilter: "top25",
      });
      const all = new Set(sections.flatMap((s) => s.games.map((g) => g.id)));
      expect(all).toEqual(new Set([liveB1g.id]));
    }
  });

  it("returns no sections when the filters clear the slate", () => {
    const sections = buildSections([preSec], {
      grouping: "date",
      ...noFollows,
      liveOnly: true,
    });
    expect(sections).toEqual([]);
  });
});

describe("filter labels", () => {
  it("names conference tokens via the registry, with chip short forms", () => {
    expect(scoreFilterLabel("conference-8")).toBe("SEC");
    expect(scoreFilterLabel("top25")).toBe("Top 25");
    expect(scoreFilterChipLabel("conference-12")).toBe("C-USA");
    expect(scoreFilterChipLabel("conference-17")).toBe("MWC");
    expect(scoreFilterChipLabel("conference-18")).toBe("Indep.");
    expect(scoreFilterChipLabel("conference-8")).toBe("SEC");
  });
});
