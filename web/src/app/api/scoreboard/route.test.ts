import { afterEach, describe, expect, it, vi } from "vitest";
import { EspnApiError } from "@/lib/espn";

/**
 * The route's half of the diagnostic chain.
 *
 * Every ESPN failure comes back as a 502, which is right — the upstream
 * status describes ESPN's answer, not ours. What was missing is the number
 * itself, so a blank Scores screen could not say which failure it was
 * (2026-09-17).
 */

const scoreboardForDays = vi.fn();
const scoreboardForDateTokens = vi.fn();
const scoreboard = vi.fn();

vi.mock("@/lib/espn", async () => {
  const actual = await vi.importActual<typeof import("@/lib/espn")>("@/lib/espn");
  return {
    ...actual,
    scoreboardForDays: (...args: unknown[]) => scoreboardForDays(...args),
    scoreboardForDateTokens: (...args: unknown[]) =>
      scoreboardForDateTokens(...args),
    scoreboard: (...args: unknown[]) => scoreboard(...args),
  };
});

const { GET } = await import("./route");

function request(query: string) {
  return new Request(
    `https://statside.co/api/scoreboard?${query}`
  ) as unknown as Parameters<typeof GET>[0];
}

afterEach(() => {
  vi.clearAllMocks();
});

describe("GET /api/scoreboard", () => {
  it("forwards ESPN's status as upstreamStatus", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    scoreboardForDays.mockRejectedValue(
      new EspnApiError(404, "https://site.api.espn.com/…/scoreboard")
    );

    const response = await GET(
      request("league=cfb&start=2026-09-15&end=2026-09-19")
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toMatchObject({ upstreamStatus: 404 });
  });

  it("omits upstreamStatus for a failure that never reached ESPN", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    scoreboardForDays.mockRejectedValue(new TypeError("fetch failed"));

    const response = await GET(
      request("league=nfl&start=2026-09-15&end=2026-09-19")
    );

    expect(response.status).toBe(502);
    expect((await response.json()).upstreamStatus).toBeUndefined();
  });

  it("still rejects an unknown league before asking ESPN", async () => {
    const response = await GET(request("league=mlb"));

    expect(response.status).toBe(400);
    expect(scoreboardForDays).not.toHaveBeenCalled();
  });

  it("returns the board on success", async () => {
    scoreboardForDays.mockResolvedValue({ league: "cfb", games: [] });

    const response = await GET(
      request("league=cfb&start=2026-09-15&end=2026-09-19")
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ league: "cfb" });
  });

  it("asks for ESPN's own days when the live poll names them", async () => {
    scoreboardForDateTokens.mockResolvedValue([]);

    const response = await GET(
      request("league=cfb&dates=20260925,20260926")
    );

    expect(response.status).toBe(200);
    expect(scoreboardForDateTokens).toHaveBeenCalledWith(
      "cfb",
      ["20260925", "20260926"],
      { groups: undefined }
    );
    expect(scoreboardForDays).not.toHaveBeenCalled();
    expect(await response.json()).toEqual({ league: "cfb", games: [] });
  });

  it("rejects malformed or too many date tokens before asking ESPN", async () => {
    for (const dates of ["2026-09-25", "20260925,x", "1,2,3,4", ""]) {
      const response = await GET(request(`league=cfb&dates=${dates}`));
      expect(response.status).toBe(400);
    }
    expect(scoreboardForDateTokens).not.toHaveBeenCalled();
  });
});
