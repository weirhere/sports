// The leaders' season fallback and name resolution, with ESPN stubbed at
// `fetch` and the roster at the provider — the parts of `teamLeaders` that
// are rules rather than shapes.

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { TeamRoster } from "@/lib/types";

const roster: TeamRoster = {
  groups: [
    {
      name: "Players",
      players: [
        {
          id: "3917376",
          name: "Jaylen Brown",
          headshotUrl: "https://a.espncdn.com/i/headshots/nba/players/full/3917376.png",
        },
      ],
    },
  ],
};

vi.mock("./provider", () => ({
  teamRoster: vi.fn(async () => roster),
}));

const { teamLeaders, teamSeasonStats } = await import("./team-stats-provider");

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status });
}

describe("teamLeaders", () => {
  let requested: string[];

  beforeEach(() => {
    requested = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        requested.push(url);
        if (url.includes("/seasons/2027/")) {
          return json({ error: { message: "No stats found.", code: 404 } }, 404);
        }
        if (url.endsWith("/teams/2/leaders")) {
          return json({
            categories: [
              {
                name: "pointsPerGame",
                displayName: "Points Per Game",
                leaders: [{ displayValue: "28.7", athlete: { $ref: "http://x/seasons/2026/athletes/3917376?lang=en" } }],
              },
              {
                name: "reboundsPerGame",
                displayName: "Rebounds Per Game",
                leaders: [{ displayValue: "9.1", athlete: { $ref: "http://x/seasons/2026/athletes/111?lang=en" } }],
              },
              {
                name: "assistsPerGame",
                displayName: "Assists Per Game",
                leaders: [{ displayValue: "6.0", athlete: { $ref: "http://x/seasons/2026/athletes/222?lang=en" } }],
              },
            ],
          });
        }
        if (url.endsWith("/athletes/111")) {
          return json({ displayName: "Traded Away", headshot: { href: "https://example.com/h.png" } });
        }
        // Athlete 222: nobody can name them.
        return json({}, 404);
      })
    );
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("falls back a season in September and says which", async () => {
    const result = await teamLeaders("nba", "2", new Date(2026, 8, 25));
    expect(requested[0]).toContain("/seasons/2027/types/2/teams/2/leaders");
    expect(requested[1]).toContain("/seasons/2026/types/2/teams/2/leaders");
    expect(result.seasonLabel).toBe("2025-26");
  });

  it("names leaders off the roster first, then the athlete record, and drops the rest", async () => {
    const result = await teamLeaders("nba", "2", new Date(2026, 8, 25));
    expect(result.leaders.map((l) => [l.name, l.onRoster])).toEqual([
      ["Jaylen Brown", true],
      ["Traded Away", false],
    ]);
    // Row-sized, not the 600px press photo.
    expect(result.leaders[0].headshotUrl).toContain("/combiner/i?img=");
    // The athlete lookup asks the season the leaders answered for.
    expect(requested).toContain(
      "https://sports.core.api.espn.com/v2/sports/basketball/leagues/nba/seasons/2026/athletes/111"
    );
  });

  it("answers empty when neither season has leaders", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => json({}, 404)));
    const result = await teamLeaders("nhl", "1", new Date(2026, 8, 25));
    expect(result).toEqual({ leaders: [] });
  });
});

describe("teamSeasonStats", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("answers empty rather than throwing when ESPN is unreachable", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new TypeError("fetch failed");
      })
    );
    const stats = await teamSeasonStats("cfb", "194");
    expect(stats.categories).toEqual([]);
  });
});
