import { afterEach, describe, expect, it, vi } from "vitest";
import { ApiError, getScoreboardDays } from "@/lib/api";

/**
 * The diagnostic chain, end to end.
 *
 * ESPN's own status used to die at the API route, which mapped every
 * upstream failure to a flat 502 — so the browser knew only that
 * *something* went wrong, and "something went wrong" is what the Scores
 * screen had to print. On 2026-09-17 that left a blank slate with no way to
 * tell "they moved the endpoint" from "ESPN is down". These pin the
 * forwarding.
 */

const originalFetch = globalThis.fetch;

afterEach(() => {
  globalThis.fetch = originalFetch;
  vi.restoreAllMocks();
});

function respondWith(body: unknown, status: number) {
  globalThis.fetch = vi.fn(async () =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json" },
    })
  ) as unknown as typeof fetch;
}

describe("getScoreboardDays", () => {
  it("carries ESPN's status through the route's 502", async () => {
    respondWith({ error: "Failed to fetch scoreboard", upstreamStatus: 404 }, 502);

    const failure = await getScoreboardDays(
      "cfb",
      new Date(2026, 8, 15),
      new Date(2026, 8, 19)
    ).catch((reason: unknown) => reason);

    expect(failure).toBeInstanceOf(ApiError);
    const error = failure as ApiError;
    expect(error.status).toBe(502);
    // The number the screen prints, and the whole point of the change.
    expect(error.upstreamStatus).toBe(404);
  });

  it("still fails cleanly when the route reports no upstream status", async () => {
    // A route that threw before it ever reached ESPN has no status to give.
    respondWith({ error: "Failed to fetch scoreboard" }, 502);

    const failure = await getScoreboardDays(
      "nfl",
      new Date(2026, 8, 15),
      new Date(2026, 8, 19)
    ).catch((reason: unknown) => reason);

    expect(failure).toBeInstanceOf(ApiError);
    expect((failure as ApiError).upstreamStatus).toBeUndefined();
  });

  it("survives an error body that isn't JSON", async () => {
    // A gateway-level failure answers HTML, and parsing it must not replace
    // the real error with a SyntaxError.
    globalThis.fetch = vi.fn(async () =>
      new Response("<html>504 Gateway Timeout</html>", { status: 504 })
    ) as unknown as typeof fetch;

    const failure = await getScoreboardDays(
      "nba",
      new Date(2026, 8, 15),
      new Date(2026, 8, 19)
    ).catch((reason: unknown) => reason);

    expect(failure).toBeInstanceOf(ApiError);
    expect((failure as ApiError).status).toBe(504);
    expect((failure as ApiError).upstreamStatus).toBeUndefined();
  });

  it("returns the board on success", async () => {
    respondWith({ league: "cfb", games: [] }, 200);

    const board = await getScoreboardDays(
      "cfb",
      new Date(2026, 8, 15),
      new Date(2026, 8, 19)
    );

    expect(board.games).toEqual([]);
  });
});
