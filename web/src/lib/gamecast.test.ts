import { describe, expect, it } from "vitest";
import type { Game, PlayItem, Team } from "@/lib/types";
import type { League } from "@/lib/leagues";
import {
  currentShotMap,
  footballGamecast,
  leadChanges,
  margin,
  remainingClock,
  run,
  shotMapGamecast,
  teamMarkHex,
} from "./gamecast";

const AWAY = "20";
const HOME = "27";

function team(id: string, abbreviation: string, school: string): Team {
  return {
    id,
    espnId: Number(id),
    league: "nba",
    name: "Team",
    school,
    abbreviation,
    conferenceId: "0",
    conferenceName: "",
    logoUrl: `https://a.espncdn.com/i/teamlogos/nba/500/${id}.png`,
  };
}

function game(league: League = "nba"): Game {
  return {
    id: "401",
    league,
    status: "in_progress",
    scheduledAt: "2026-09-05T16:00Z",
    venue: { name: "Arena", city: "City", state: "ST" },
    awayTeam: { team: team(AWAY, "PHI", "Philadelphia"), score: null },
    homeTeam: { team: team(HOME, "WSH", "Washington"), score: null },
    seasonYear: 2026,
    conferenceGame: false,
  };
}

let nextId = 0;
function play(over: Partial<PlayItem> = {}): PlayItem {
  nextId += 1;
  return { id: `p${nextId}`, isScoringPlay: false, period: 1, ...over };
}

const score = (awayScore: number, homeScore: number) =>
  play({ awayScore, homeScore });

describe("basketball's columns", () => {
  it("counts a run as the points one side scored since the other last did", () => {
    const plays = [score(0, 2), score(2, 2), score(5, 2), score(7, 2)];
    expect(run(plays)).toEqual({ side: "away", points: 7 });
    expect(run([play()])).toBeUndefined();
  });

  it("reads the lead off the last scored play", () => {
    expect(margin([score(7, 2), play()])).toBe(5);
    expect(margin([play()])).toBeUndefined();
  });

  it("counts a lead change only when the lead passes, not at a tie", () => {
    const plays = [score(2, 0), score(2, 2), score(2, 4), score(4, 4), score(4, 6), score(7, 6)];
    // away → (tie) → home → (tie) → home → away: two changes.
    expect(leadChanges(plays)).toBe(2);
  });

  it("prints Run · Lead · Lead changes and no result", () => {
    const content = shotMapGamecast(
      game(),
      [score(0, 2), score(3, 2), play({ text: "Maxey makes free throw", clock: "4:12", awayScore: 4, homeScore: 2 })],
      false
    )!;
    expect(content.slots.map((s) => s.value)).toEqual(["PHI 4–0", "PHI +2", "1"]);
    expect(content.result).toBeUndefined();
    expect(content.lastPlayClock).toBe("4:12");
    expect(content.accessibilitySummary).toContain("Philadelphia on a 4–0 run");
  });
});

describe("hockey's columns", () => {
  it("converts ESPN's counting-up clock to time remaining", () => {
    expect(remainingClock("0:29", 1, true)).toBe("19:31");
    expect(remainingClock("1:00", 4, true)).toBe("4:00");
    expect(remainingClock("1:00", 4, false)).toBe("19:00");
    expect(remainingClock("junk", 1, false)).toBe("junk");
  });

  it("holds GOAL from the goal until the next faceoff", () => {
    const g = game("nhl");
    const goal = play({ typeText: "Goal", teamId: HOME, clock: "5:00", awayScore: 0, homeScore: 1 });
    const standing = shotMapGamecast(g, [play({ typeText: "Shot", teamId: AWAY }), goal], true)!;
    expect(standing.result).toBe("Goal");
    expect(standing.resultTeam?.abbreviation).toBe("WSH");
    expect(standing.slots.map((s) => s.value)).toEqual([undefined, "1–1", "WSH 15:00"]);

    const restarted = shotMapGamecast(g, [goal, play({ typeText: "Face Off", teamId: AWAY })], true)!;
    expect(restarted.result).toBeUndefined();
  });

  it("names the side on the power play, from either end of the play", () => {
    const g = game("nhl");
    const pp = shotMapGamecast(g, [play({ strength: "power-play", teamId: AWAY })], true)!;
    expect(pp.slots[0].value).toBe("PHI PP");
    expect(pp.lastPlayLabel).toBe("Last play · Power play");
    const shorty = shotMapGamecast(g, [play({ strength: "short-handed", teamId: AWAY })], true)!;
    expect(shorty.slots[0].value).toBe("WSH PP");
  });

  it("gives an earlier period's goal its period, not a clock", () => {
    const g = game("nhl");
    const content = shotMapGamecast(
      g,
      [play({ typeText: "Goal", teamId: AWAY, period: 1 }), play({ typeText: "Face Off", period: 2 })],
      true
    )!;
    expect(content.slots[2].value).toBe("PHI 1st");
  });
});

describe("the shot map", () => {
  it("unfolds each team's shots to the basket it attacks", () => {
    const map = currentShotMap(
      game(),
      [
        play({ teamId: HOME, isShootingPlay: true, coordinate: { x: 19, y: 12 } }),
        play({ teamId: AWAY, isShootingPlay: true, isScoringPlay: true, coordinate: { x: 19, y: 12 } }),
        play({ teamId: AWAY, coordinate: { x: 1, y: 1 } }), // not a shot
      ],
      false
    )!;
    expect(map.surface).toBe("court");
    expect(map.marks).toEqual([
      expect.objectContaining({ side: "home", x: 12, y: 19, outcome: "missed" }),
      expect.objectContaining({ side: "away", x: 82, y: 31, outcome: "made" }),
    ]);
  });

  it("keeps only the current period", () => {
    const map = currentShotMap(
      game(),
      [
        play({ period: 1, teamId: HOME, isShootingPlay: true, coordinate: { x: 1, y: 1 } }),
        play({ period: 2, teamId: HOME, isShootingPlay: true, coordinate: { x: 2, y: 2 } }),
      ],
      false
    )!;
    expect(map.period).toBe(2);
    expect(map.marks).toHaveLength(1);
  });

  it("turns the rink so the away team always shoots right", () => {
    const g = game("nhl");
    const leftward = [
      play({ typeText: "Shot", teamId: AWAY, coordinate: { x: -80, y: 10 } }),
      play({ typeText: "Goal", teamId: AWAY, coordinate: { x: -85, y: 0 } }),
      play({ typeText: "Blocked", teamId: HOME, coordinate: { x: -60, y: 0 } }),
    ];
    const map = currentShotMap(g, leftward, true)!;
    expect(map.surface).toBe("rink");
    expect(map.marks[0]).toMatchObject({ x: 180, y: 52.5, outcome: "made" });
    expect(map.marks[1]).toMatchObject({ x: 185, outcome: "goal" });
    expect(map.marks[2]).toMatchObject({ outcome: "blocked" });
  });

  it("draws nothing in a shootout or in football", () => {
    const shootout = [play({ period: 5, typeText: "Goal", teamId: AWAY, coordinate: { x: 80, y: 0 } })];
    expect(currentShotMap(game("nhl"), shootout, true)).toBeUndefined();
    expect(currentShotMap(game("cfb"), [play()], false)).toBeUndefined();
  });
});

describe("the football columns", () => {
  it("prints Down · Ball on · Drive, and the touchdown in their place once scored", () => {
    const content = footballGamecast(game("cfb"), {
      possessionTeamId: AWAY,
      downDistanceText: "2nd & 4",
      possessionText: "WSU 26",
      driveLine: "4 plays, 57 yds",
      lastPlayDownText: "1st & 10 at WSU 20",
      drivingRight: true,
    });
    expect(content.slots.map((s) => s.value)).toEqual(["2nd & 4", "WSU 26", "4 plays, 57 yds"]);
    expect(content.lastPlayLabel).toBe("Last play · 1st & 10 at WSU 20");
    expect(content.accessibilitySummary).toBe("Philadelphia ball, 2nd & 4, WSU 26, 4 plays, 57 yds");

    const scored = footballGamecast(game("cfb"), {
      possessionTeamId: AWAY,
      result: "Touchdown",
      resultTeamId: HOME,
      drivingRight: true,
    });
    expect(scored.resultTeam?.abbreviation).toBe("WSH");
    expect(scored.accessibilitySummary).toBe("Washington touchdown");
  });
});

describe("team marks", () => {
  it("falls back to the alternate when the primary would vanish", () => {
    // Near-black on a black page; near-white on a white one.
    expect(teamMarkHex("#000000", "#ba0c2f", true)).toBe("#ba0c2f");
    expect(teamMarkHex("#000000", "#ba0c2f", false)).toBe("#000000");
    expect(teamMarkHex("ffffff", "002b5c", false)).toBe("#002b5c");
    expect(teamMarkHex("ffffff", "fefefe", false)).toBeUndefined();
    expect(teamMarkHex(undefined, "nothex", false)).toBeUndefined();
  });
});
