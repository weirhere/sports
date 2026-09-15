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
 * **Driven by an external pinger at 60-second intervals** (Andy, 2026-09-15),
 * not by Vercel Cron — Cron on the Hobby plan fires once a day, and minute
 * granularity needs Pro, which this project does not need until it charges
 * for something. There is no `vercel.json`, and the previous version of this
 * comment pointed at one that never existed. See
 * `docs/live-activities-service.md` § The scheduler decision.
 *
 * Guarded by a shared secret so it isn't an open relay for anyone who finds
 * the URL. That matters more with a pinger than it would with Cron: the URL
 * is configured in a third party's dashboard rather than in this repo.
 *
 * **The tick is unconditional, and the pinger's schedule is what bounds it.**
 * Nothing here can know whether anything is live without asking ESPN, so
 * every tick costs four scoreboard requests whether or not a ball is in the
 * air. At 60s that is ~5,760 requests a day if the pinger runs around the
 * clock, which is politeness spent on an empty Tuesday at 3am. Bound it by
 * scheduling the pinger over plausible game windows instead. Doing better in
 * code means caching the next kickoff and skipping the fetch until then,
 * which is state this service deliberately does not hold yet.
 */
export const dynamic = "force-dynamic";
export const maxDuration = 60;

const LEAGUES: League[] = ["cfb", "nfl", "nba", "nhl"];

/** Two ticks' grace at the decided 60-second cadence, matching the client's
 *  own staleDate. A card whose updates stop says so rather than freezing on
 *  a wrong score. **Move this if the cadence moves** — it is 2 × the tick,
 *  and it was the only thing in the repo that knew the cadence was 60s back
 *  when the blocker still claimed the target was 30. */
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
