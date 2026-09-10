import { NextResponse } from "next/server";
import { scoreboard } from "@/lib/espn/provider";
import { apnsConfigFromEnv, sendBroadcast } from "@/lib/apns";
import { staticChannelDirectory } from "@/lib/live-activity-channels";
import { activityPhase, contentState } from "@/lib/live-activity-state";
import type { League } from "@/lib/leagues";

/**
 * The poll loop: one pass over the live slate, one broadcast per live game
 * that has a channel.
 *
 * **This is the shape the whole path-3 argument rests on.** One ESPN
 * request per league per tick and one APNs push per live game, whether ten
 * people or ten thousand are watching — load is a function of the slate,
 * not of the install base, which is the only version the polite-guest rule
 * survives. Nothing here reads or writes anything about a user.
 *
 * Driven by Vercel Cron (see vercel.json). Guarded by a shared secret so it
 * isn't an open relay for anyone who finds the URL.
 */
export const dynamic = "force-dynamic";
export const maxDuration = 60;

const LEAGUES: League[] = ["cfb", "nfl", "nba", "nhl"];

/** Two ticks' grace, matching the client's own staleDate. A card whose
 *  updates stop says so rather than freezing on a wrong score. */
const STALE_AFTER_SECONDS = 120;

function authorized(request: Request): boolean {
  const expected = process.env.LIVE_ACTIVITY_CRON_SECRET;
  // No secret configured means the endpoint is closed, not open: an
  // unguarded push relay is worse than a missing feature.
  if (!expected) return false;
  const header = request.headers.get("authorization");
  return header === `Bearer ${expected}`;
}

export async function GET(request: Request) {
  if (!authorized(request)) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const config = apnsConfigFromEnv();
  if (!config) {
    // The normal state until the provider key exists. Reported rather than
    // failed, so a cron run doesn't page anybody over a feature that simply
    // isn't configured yet.
    return NextResponse.json({ status: "apns-not-configured", pushed: 0 });
  }

  const channels = staticChannelDirectory();
  const now = new Date();
  const results: { gameId: string; league: League; ok: boolean; reason?: string }[] = [];

  const slates = await Promise.all(
    LEAGUES.map(async (league) => {
      try {
        return { league, games: (await scoreboard(league)).games };
      } catch {
        // One league failing must not take the others' updates down.
        return { league, games: [] };
      }
    }),
  );

  for (const { league, games } of slates) {
    for (const game of games) {
      const phase = activityPhase(game.status);
      if (phase === "pre") continue; // nothing on a pre-game card moves
      const channelId = await channels.channelId(game.id, league);
      if (!channelId) continue;

      const state = contentState(game, { now });
      const isFinal = phase === "final";
      const result = await sendBroadcast(config, {
        channelId,
        contentState: state as unknown as Record<string, unknown>,
        // A final ends the card rather than updating it — the client's own
        // spent rule retires it too, but a push is what reaches a phone
        // nobody has opened.
        event: isFinal ? "end" : "update",
        staleDate: isFinal ? undefined : state.asOf + STALE_AFTER_SECONDS,
        priority: 10,
      });
      results.push({ gameId: game.id, league, ok: result.ok, reason: result.reason });
    }
  }

  return NextResponse.json({
    status: "ok",
    at: now.toISOString(),
    pushed: results.filter((r) => r.ok).length,
    failed: results.filter((r) => !r.ok),
  });
}
