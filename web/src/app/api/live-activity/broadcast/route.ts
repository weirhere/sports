import { NextResponse } from "next/server";
import { scoreboard } from "@/lib/espn/provider";
import { apnsConfigFromEnv, deleteChannel, sendBroadcast } from "@/lib/apns";
import { kvFromEnv } from "@/lib/kv";
import {
  channelKey,
  isReapable,
  kvChannelStore,
  parseChannelMap,
  staticChannelDirectory,
  type ChannelRecord,
} from "@/lib/live-activity-channels";
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

/** How long a `end` push stays worth delivering. Well inside the 8 hours a
 *  most-recent-message channel will store, and long enough that a phone put
 *  down before the fourth quarter still comes back to the right result. */
const FINAL_EXPIRY_SECONDS = 3600;

/** Per-league accounting for the response.
 *
 * Added 2026-09-15, after a live game with a correctly configured channel
 * produced `pushed: 0, failed: []` and there was no way to tell from the
 * outside whether the slate was empty, the fetch had thrown, the phase had
 * skipped it, or the channel id hadn't matched. Four causes, one response.
 * The route's only consumer is a pinger and a person with curl, so the
 * response *is* the log. */
interface LeagueReport {
  league: League;
  /** Games the scoreboard returned. */
  games: number;
  /**
   * Of those, the ones past pre-game — the candidates for a push.
   *
   * **Not "in progress."** A final counts here, because a final is pushed
   * too (as an `end` event). The first response this field ever produced
   * read `nfl: games 16, live 16` on a night with exactly one game in
   * progress and fifteen finished, which is accurate and reads as a lie —
   * hence the name it has now.
   */
  eligible: number;
  /** Of those, the ones that resolved a channel id. */
  matched: number;
  /** Present only when the scoreboard fetch threw for this league. */
  error?: string;
}

/** An error's message, never the object — this lands in a JSON response. */
function describe(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

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

  // Channels made on demand live in the store (2026-09-24); without one,
  // the hand-made `APNS_CHANNELS` map is still read, as before.
  const kv = kvFromEnv();
  const store = kv ? kvChannelStore(kv) : null;
  const stored = new Map<string, ChannelRecord>(store ? await store.entries() : []);
  const staticChannels = staticChannelDirectory();
  const channelCount = store
    ? stored.size
    : Object.keys(parseChannelMap(process.env.APNS_CHANNELS)).length;
  const now = new Date();
  const nowSeconds = Math.floor(now.getTime() / 1000);
  const results: { gameId: string; league: League; ok: boolean; reason?: string }[] = [];
  const reports: LeagueReport[] = [];

  const slates = await Promise.all(
    LEAGUES.map(async (league) => {
      try {
        // `error: undefined` on the happy path so both branches carry the
        // same shape — without it the union has no `error` to destructure.
        return { league, games: (await scoreboard(league)).games, error: undefined };
      } catch (error) {
        // One league failing must not take the others' updates down — but
        // it must not look like a quiet night either. The message rides
        // into the response so a zero is attributable.
        return { league, games: [], error: describe(error) };
      }
    }),
  );

  for (const { league, games, error } of slates) {
    const report: LeagueReport = { league, games: games.length, eligible: 0, matched: 0 };
    if (error) report.error = error;
    reports.push(report);

    for (const game of games) {
      const phase = activityPhase(game.status);
      if (phase === "pre") continue; // nothing on a pre-game card moves
      report.eligible += 1;
      const key = channelKey(game.id, league);
      const record = stored.get(key);
      const channelId = store
        ? record?.channelId
        : await staticChannels.channelId(game.id, league);
      if (!channelId) continue;
      report.matched += 1;

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
        // Required by APNs, and the value is a product decision rather than
        // a formality. An update is worthless once the card it would land on
        // has already gone stale — that would put a two-tick-old score on a
        // lock screen — so an update dies at its own stale date. A final is
        // worth an hour: a phone that was off during the fourth quarter
        // should still come back to a dismissed card and the right result.
        expiration: state.asOf + (isFinal ? FINAL_EXPIRY_SECONDS : STALE_AFTER_SECONDS),
        priority: 10,
      });
      results.push({ gameId: game.id, league, ok: result.ok, reason: result.reason });
      // The first `end` starts the clock on the channel's retirement: it
      // is kept as long as that stored `end` is worth delivering.
      if (store && record && isFinal && result.ok && record.endedAt === undefined) {
        const ended = { ...record, endedAt: nowSeconds };
        await store.replace(key, ended);
        stored.set(key, ended);
      }
    }
  }

  // The reaper. Every channel made has to be unmade — Apple caps an app at
  // 10,000 per environment — and a record is only removed once Apple has
  // confirmed the delete, so a failed one is retried on the next tick
  // rather than orphaned.
  const reaped: string[] = [];
  const reapFailed: { key: string; reason?: string }[] = [];
  if (store) {
    for (const [key, record] of stored) {
      if (!isReapable(record, nowSeconds)) continue;
      const result = await deleteChannel(config, record.channelId);
      // 404: already gone at Apple, so the record is all that's left.
      if (result.ok || result.status === 404) {
        await store.remove(key);
        reaped.push(key);
      } else {
        reapFailed.push({ key, reason: result.reason ?? String(result.status) });
      }
    }
  }

  return NextResponse.json({
    status: "ok",
    at: now.toISOString(),
    pushed: results.filter((r) => r.ok).length,
    failed: results.filter((r) => !r.ok),
    // Why the number above is the number above. `channels` is the size of
    // the configured map, so `matched: 0` against a non-zero `channels`
    // says the ids don't line up, and `matched: 0` against `channels: 0`
    // says nothing is configured — two very different problems that used
    // to produce the identical response. `eligible` counts everything past
    // pre-game rather than everything in progress, finals included, because
    // that is the set this loop will try to push to.
    channels: channelCount,
    store: store ? "kv" : "static",
    reaped,
    reapFailed,
    leagues: reports,
  });
}
