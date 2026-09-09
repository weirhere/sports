import { describe, expect, it } from "vitest";
import type { Game, GameStatus, GameTeam, Team } from "./types";
import type { League } from "./leagues";
import type { FollowedTable } from "./followed-tables";
import {
  buildSections,
  FOLLOWING_SECTION_ID,
  scoreFilterChipLabel,
  scoreFilterLabel,
} from "./game-sections";

function team(
  id: string,
  school: string,
  conferenceId: string,
  league: League = "cfb"
): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name: school,
    school,
    abbreviation: school.slice(0, 3).toUpperCase(),
    conferenceId,
    conferenceName: "",
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
  league?: League;
}): Game {
  return {
    id: fields.id ?? `g${nextId++}`,
    league: fields.league ?? fields.home.team.league,
    status: fields.status ?? "scheduled",
    scheduledAt: fields.scheduledAt ?? "2026-09-05T19:30:00Z",
    venue: { name: "", city: "", state: "" },
    homeTeam: fields.home,
    awayTeam: fields.away,
    seasonYear: 2026,
    conferenceGame: false,
  };
}

// College football registry ids: SEC 8, Big Ten 5, MAC 15, Sun Belt 37;
// "0" is unknown. NFL: the Bills (2) and the Chiefs (12) — their conference
// ids come from the hardcoded registry, so the fixtures carry the divisions
// ESPN's own standings report.
const georgia = team("61", "Georgia", "8");
const alabama = team("333", "Alabama", "8");
const michigan = team("130", "Michigan", "5");
const ohioState = team("194", "Ohio State", "5");
const toledo = team("2649", "Toledo", "15");
const troy = team("2653", "Troy", "37");
const fcsVisitor = team("2755", "Wofford", "0");
const bills = team("2", "Buffalo", "4", "nfl"); // AFC East
const chiefs = team("12", "Kansas City", "6", "nfl"); // AFC West
const celtics = team("2", "Boston", "1", "nba"); // Atlantic
const knicks = team("18", "New York", "1", "nba");

const noFollows = { followedTeamKeys: [] as string[] };

describe("the stack", () => {
  it("splits college football by conference and stands every other league whole", () => {
    // 60 college rows on a Saturday need carving; a 16-game NFL Sunday is
    // the whole slate at a glance.
    const sections = buildSections(
      [
        game({ home: side(georgia), away: side(alabama) }),
        game({ home: side(michigan), away: side(ohioState) }),
        game({ home: side(bills), away: side(chiefs) }),
        game({ home: side(celtics), away: side(knicks) }),
      ],
      noFollows
    );
    expect(sections.map((s) => s.id)).toEqual([
      "conf-cfb:5",
      "conf-cfb:8",
      "league-nfl",
      "league-nba",
    ]);
  });

  it("orders the stack P4 → G5 → Independents, then league by league", () => {
    const sections = buildSections(
      [
        game({ home: side(toledo), away: side(troy) }),
        game({ home: side(georgia), away: side(alabama) }),
        game({ home: side(bills), away: side(chiefs) }),
      ],
      noFollows
    );
    expect(sections.map((s) => s.title)).toEqual([
      "SEC",
      "MAC",
      "Sun Belt",
      "NFL",
    ]);
  });

  it("duplicates a cross-conference game into both conferences", () => {
    // Sections are complete, never deduplicated.
    const crossover = game({ home: side(georgia), away: side(michigan) });
    const sections = buildSections([crossover], noFollows);
    expect(sections.map((s) => s.id).sort()).toEqual([
      "conf-cfb:5",
      "conf-cfb:8",
    ]);
    for (const section of sections) {
      expect(section.games).toHaveLength(1);
    }
  });

  it("keeps an FCS visitor in its host's conference only, never in Other", () => {
    // Week 1's ~48 FCS matchups would otherwise pile up in Other.
    const sections = buildSections(
      [game({ home: side(georgia), away: side(fcsVisitor) })],
      noFollows
    );
    expect(sections.map((s) => s.id)).toEqual(["conf-cfb:8"]);
  });

  it("buckets both-sides-unknown games into Other, per league", () => {
    const stranger = team("9999", "Nobody", "0");
    const sections = buildSections(
      [game({ home: side(stranger), away: side(fcsVisitor) })],
      noFollows
    );
    expect(sections.map((s) => s.id)).toEqual(["other-cfb"]);
    expect(sections[0].title).toBe("Other");
  });

  it("tags a section with its league, except where the title already says it", () => {
    const sections = buildSections(
      [
        game({ home: side(georgia), away: side(alabama) }),
        game({ home: side(bills), away: side(chiefs) }),
      ],
      noFollows
    );
    expect(sections.find((s) => s.title === "SEC")?.league).toBe("cfb");
    // The NFL's own section is titled "NFL" — the header suppresses the tag
    // from that, not from a missing league.
    expect(sections.find((s) => s.title === "NFL")?.league).toBe("nfl");
  });
});

describe("Following is your teams", () => {
  it("leads with a Following section spanning leagues", () => {
    const sections = buildSections(
      [
        game({ home: side(georgia), away: side(alabama) }),
        game({ home: side(bills), away: side(chiefs) }),
        game({ home: side(toledo), away: side(troy) }),
      ],
      { followedTeamKeys: ["cfb:61", "nfl:2"] }
    );
    expect(sections[0].id).toBe(FOLLOWING_SECTION_ID);
    expect(sections[0].games).toHaveLength(2);
    // And the games stay in their own sections too — completeness.
    expect(sections.some((s) => s.id === "conf-cfb:8")).toBe(true);
    expect(sections.some((s) => s.id === "league-nfl")).toBe(true);
  });

  it("matches on the league-qualified key, never a bare id", () => {
    // ESPN id 2 is Auburn *and* the Bills. Following the Bills must not
    // claim a college game.
    const auburn = team("2", "Auburn", "8");
    const sections = buildSections(
      [
        game({ home: side(auburn), away: side(alabama) }),
        game({ home: side(bills), away: side(chiefs) }),
      ],
      { followedTeamKeys: ["nfl:2"] }
    );
    expect(sections[0].id).toBe(FOLLOWING_SECTION_ID);
    expect(sections[0].games).toHaveLength(1);
    expect(sections[0].games[0].league).toBe("nfl");
  });

  it("orders Following live first, then upcoming, then finals", () => {
    // A final has nothing left to say while a live game changes every play.
    const games = [
      game({
        id: "final",
        home: side(georgia),
        away: side(alabama),
        status: "complete",
        scheduledAt: "2026-09-05T16:00:00Z",
      }),
      game({
        id: "live",
        home: side(michigan),
        away: side(ohioState),
        status: "in_progress",
        scheduledAt: "2026-09-05T20:00:00Z",
      }),
      game({
        id: "next",
        home: side(toledo),
        away: side(troy),
        status: "scheduled",
        scheduledAt: "2026-09-05T23:00:00Z",
      }),
    ];
    const sections = buildSections(games, {
      followedTeamKeys: ["cfb:61", "cfb:130", "cfb:2649"],
    });
    expect(sections[0].games.map((g) => g.id)).toEqual([
      "live",
      "next",
      "final",
    ]);
  });

  it("does NOT pour a followed conference's slate into Following", () => {
    // A Big Ten follow is ~8 games on a Saturday, which buries the three
    // you actually care about (iOS, 2026-09-06).
    const bigTen: FollowedTable = {
      kind: "conference",
      ref: { league: "cfb", id: 5 },
    };
    const sections = buildSections(
      [
        game({ home: side(michigan), away: side(ohioState) }),
        game({ home: side(georgia), away: side(alabama) }),
      ],
      { followedTeamKeys: [], followedTables: [bigTen] }
    );
    expect(sections.some((s) => s.id === FOLLOWING_SECTION_ID)).toBe(false);
  });
});

describe("followed tables get hoisted", () => {
  const bigTen: FollowedTable = {
    kind: "conference",
    ref: { league: "cfb", id: 5 },
  };

  it("moves a conference's own section up the stack rather than cloning it", () => {
    const sections = buildSections(
      [
        game({ home: side(georgia), away: side(alabama) }),
        game({ home: side(michigan), away: side(ohioState) }),
      ],
      { followedTeamKeys: [], followedTables: [bigTen] }
    );
    expect(sections.map((s) => s.id)).toEqual(["conf-cfb:5", "conf-cfb:8"]);
    // Exactly one Big Ten section, not two.
    expect(sections.filter((s) => s.id === "conf-cfb:5")).toHaveLength(1);
  });

  it("builds a section for a table the stack has no counterpart for", () => {
    // The AFC is not one of the NFL's Scores sections — the league stands
    // whole — so following it adds a section, and the games repeat below.
    const afc: FollowedTable = {
      kind: "conference",
      ref: { league: "nfl", id: 8 },
    };
    const sections = buildSections(
      [game({ home: side(bills), away: side(chiefs) })],
      { followedTeamKeys: [], followedTables: [afc] }
    );
    expect(sections.map((s) => s.id)).toEqual(["conf-nfl:8", "league-nfl"]);
    expect(sections[0].title).toBe("AFC");
  });

  it("walks the group chain, so a division-stamped team matches its conference", () => {
    // ESPN's NFL scoreboard gives a team its *division* id, so "I follow
    // the AFC" only means anything if the walk-up happens.
    const afc: FollowedTable = {
      kind: "conference",
      ref: { league: "nfl", id: 8 },
    };
    const sections = buildSections(
      [game({ home: side(bills), away: side(chiefs) })],
      { followedTeamKeys: [], followedTables: [afc] }
    );
    expect(sections[0].games).toHaveLength(1);
  });

  it("honors the user's order across leagues", () => {
    const afc: FollowedTable = {
      kind: "conference",
      ref: { league: "nfl", id: 8 },
    };
    const sections = buildSections(
      [
        game({ home: side(michigan), away: side(ohioState) }),
        game({ home: side(bills), away: side(chiefs) }),
      ],
      { followedTeamKeys: [], followedTables: [afc, bigTen] }
    );
    expect(sections.slice(0, 2).map((s) => s.id)).toEqual([
      "conf-nfl:8",
      "conf-cfb:5",
    ]);
  });
});

describe("filters", () => {
  it("Live narrows every section and composes with the slate filter", () => {
    const live = game({
      home: side(georgia),
      away: side(alabama),
      status: "in_progress",
    });
    const scheduled = game({ home: side(michigan), away: side(ohioState) });
    const sections = buildSections([live, scheduled], {
      ...noFollows,
      liveOnly: true,
    });
    expect(sections.map((s) => s.id)).toEqual(["conf-cfb:8"]);
  });

  it("narrows the stack and leaves Following alone", () => {
    // Narrowing "my games" to the SEC would silently empty the section for
    // a Michigan fan — the mystery state the labeled chip exists to avoid.
    const sections = buildSections(
      [
        game({ home: side(georgia), away: side(alabama) }),
        game({ home: side(michigan), away: side(ohioState) }),
      ],
      {
        followedTeamKeys: ["cfb:130"],
        scoreFilter: "conference-cfb:8",
      }
    );
    expect(sections[0].id).toBe(FOLLOWING_SECTION_ID);
    expect(sections[0].games[0].homeTeam.team.school).toBe("Michigan");
    expect(sections.slice(1).map((s) => s.id)).toEqual(["conf-cfb:8"]);
  });

  it("hides a league the filter can't speak for outright", () => {
    // "SEC" is not a question the NFL's slate can answer.
    const sections = buildSections(
      [
        game({ home: side(georgia), away: side(alabama) }),
        game({ home: side(bills), away: side(chiefs) }),
      ],
      { ...noFollows, scoreFilter: "conference-cfb:8" }
    );
    expect(sections.map((s) => s.id)).toEqual(["conf-cfb:8"]);
  });

  it("hides a followed table the filter can't speak for", () => {
    const afc: FollowedTable = {
      kind: "conference",
      ref: { league: "nfl", id: 8 },
    };
    const sections = buildSections(
      [
        game({ home: side(georgia), away: side(alabama) }),
        game({ home: side(bills), away: side(chiefs) }),
      ],
      {
        followedTeamKeys: [],
        followedTables: [afc],
        scoreFilter: "conference-cfb:8",
      }
    );
    expect(sections.map((s) => s.id)).toEqual(["conf-cfb:8"]);
  });

  it("reads a pre-axis bare-id filter token as college football's", () => {
    const sections = buildSections(
      [game({ home: side(georgia), away: side(alabama) })],
      { ...noFollows, scoreFilter: "conference-8" }
    );
    expect(sections.map((s) => s.id)).toEqual(["conf-cfb:8"]);
  });

  it("filters to any ranked participant for Top 25", () => {
    const ranked = game({
      home: side(georgia, 3),
      away: side(alabama),
      id: "ranked",
    });
    const plain = game({ home: side(toledo), away: side(troy) });
    const sections = buildSections([ranked, plain], {
      ...noFollows,
      scoreFilter: "top25",
    });
    expect(sections.flatMap((s) => s.games).map((g) => g.id)).toEqual([
      "ranked",
    ]);
  });
});

describe("filter labels", () => {
  it("names a conference and the poll", () => {
    expect(scoreFilterLabel("top25")).toBe("Top 25");
    expect(scoreFilterLabel("conference-cfb:8")).toBe("SEC");
    expect(scoreFilterLabel("conference-nfl:8")).toBe("AFC");
  });

  it("shortens the names that would wrap a chip", () => {
    expect(scoreFilterChipLabel("conference-cfb:12")).toBe("C-USA");
    expect(scoreFilterChipLabel("conference-cfb:17")).toBe("MWC");
    expect(scoreFilterChipLabel("conference-cfb:8")).toBe("SEC");
  });
});
