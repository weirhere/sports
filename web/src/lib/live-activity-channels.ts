import type { Kv } from "@/lib/kv";

/**
 * gameId → APNs broadcast channel id.
 *
 * This is the *only* state path 3 has, and its shape is the whole reason
 * path 3 was chosen over path 2: it holds channel ids for live games, so
 * what it stores is a function of the slate rather than of the install
 * base. The moment this maps devices, it has become path 2.
 *
 * **The first cut read a static map from the environment**, filled by hand
 * from Apple's Push Notification Console. It is still read when no store is
 * configured, so local dev and tests work without one. Since 2026-09-24 the
 * real path is on demand: the first pin of a game creates its channel on
 * APNs' management host (:2195 sandbox, :2196 production) and records it in
 * Upstash Redis — the store conversation CLAUDE.md asks for, had in the
 * Coard-feedback plan. See `docs/live-activities-service.md`.
 */

export interface ChannelDirectory {
  channelId(gameId: string, league: string): Promise<string | null>;
}

/** `APNS_CHANNELS` is a JSON object keyed `"<league>:<gameId>"`. Malformed
 *  JSON resolves to an empty directory rather than throwing: a bad env var
 *  should degrade to "no channel", not take the route down. */
export function parseChannelMap(raw: string | undefined): Record<string, string> {
  if (!raw) return {};
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
    const out: Record<string, string> = {};
    for (const [key, value] of Object.entries(parsed as Record<string, unknown>)) {
      if (typeof value === "string" && value) out[key] = value;
    }
    return out;
  } catch {
    return {};
  }
}

export function channelKey(gameId: string, league: string): string {
  return `${league}:${gameId}`;
}

export function staticChannelDirectory(
  env: NodeJS.ProcessEnv = process.env,
): ChannelDirectory {
  const map = parseChannelMap(env.APNS_CHANNELS);
  return {
    async channelId(gameId, league) {
      return map[channelKey(gameId, league)] ?? null;
    },
  };
}

// --- Channels on demand (2026-09-24, E12 blocker 3) -------------------------
//
// The static map above made a person create every channel by hand in
// Apple's console, which works for one test game and not for a Saturday.
// Now the first pin of a game creates its channel and records it here, and
// the broadcast tick reaps it once the game is over. Channels exist for
// games somebody pinned, not for the whole slate, so the count and the
// push load follow what people actually watch, and still never the
// number of people watching.

/** What a stored channel knows about itself. Still no user data: a
 *  channel id, the game's kickoff, and when the game ended. */
export interface ChannelRecord {
  channelId: string;
  /** ISO kickoff, so a game that never reaches a final is still reaped. */
  kickoff: string;
  /** Epoch seconds of the first `end` push, set by the broadcast tick. */
  endedAt?: number;
}

export interface ChannelStore {
  get(key: string): Promise<ChannelRecord | null>;
  /** Writes only if nothing is there. False means another pin won. */
  putIfAbsent(key: string, record: ChannelRecord): Promise<boolean>;
  /** Overwrites an existing record, keeping its expiry. */
  replace(key: string, record: ChannelRecord): Promise<void>;
  remove(key: string): Promise<void>;
  entries(): Promise<[string, ChannelRecord][]>;
}

const PREFIX = "la:ch:";

/** A safety net under the reaper, never the reaper itself: a record that
 *  outlives this means the tick stopped running, and the channel it names
 *  is orphaned at Apple until someone deletes it. */
const RECORD_TTL_SECONDS = 48 * 3600;

function parseRecord(raw: unknown): ChannelRecord | null {
  if (typeof raw !== "string") return null;
  try {
    const value = JSON.parse(raw) as Partial<ChannelRecord>;
    if (typeof value.channelId !== "string" || typeof value.kickoff !== "string") return null;
    return {
      channelId: value.channelId,
      kickoff: value.kickoff,
      endedAt: typeof value.endedAt === "number" ? value.endedAt : undefined,
    };
  } catch {
    return null;
  }
}

export function kvChannelStore(kv: Kv): ChannelStore {
  return {
    async get(key) {
      return parseRecord(await kv.command(["GET", PREFIX + key]));
    },
    async putIfAbsent(key, record) {
      const result = await kv.command([
        "SET", PREFIX + key, JSON.stringify(record), "NX", "EX", RECORD_TTL_SECONDS,
      ]);
      return result === "OK";
    },
    async replace(key, record) {
      await kv.command(["SET", PREFIX + key, JSON.stringify(record), "XX", "KEEPTTL"]);
    },
    async remove(key) {
      await kv.command(["DEL", PREFIX + key]);
    },
    async entries() {
      const keys: string[] = [];
      let cursor = "0";
      do {
        const [next, batch] = await kv.command<[string, string[]]>([
          "SCAN", cursor, "MATCH", `${PREFIX}*`, "COUNT", 200,
        ]);
        cursor = next;
        keys.push(...batch);
      } while (cursor !== "0");
      if (keys.length === 0) return [];
      const values = await kv.command<unknown[]>(["MGET", ...keys]);
      return keys.flatMap((key, i) => {
        const record = parseRecord(values[i]);
        return record ? [[key.slice(PREFIX.length), record] as [string, ChannelRecord]] : [];
      });
    },
  };
}

/** For tests, and for nothing else. */
export function memoryChannelStore(): ChannelStore & { data: Map<string, ChannelRecord> } {
  const data = new Map<string, ChannelRecord>();
  return {
    data,
    async get(key) { return data.get(key) ?? null; },
    async putIfAbsent(key, record) {
      if (data.has(key)) return false;
      data.set(key, record);
      return true;
    },
    async replace(key, record) { if (data.has(key)) data.set(key, record); },
    async remove(key) { data.delete(key); },
    async entries() { return [...data.entries()]; },
  };
}

/**
 * The game's channel, made on first ask.
 *
 * Two pins racing on one game both create a channel at Apple; the store's
 * `SET NX` picks one, and the loser deletes its own so it isn't orphaned
 * against the 10,000 cap. Everyone gets the winner's id.
 */
export async function ensureChannel(input: {
  store: ChannelStore;
  key: string;
  kickoff: string;
  create: () => Promise<string | null>;
  destroy: (channelId: string) => Promise<void>;
}): Promise<string | null> {
  const existing = await input.store.get(input.key);
  if (existing) return existing.channelId;
  const created = await input.create();
  if (!created) return null;
  if (await input.store.putIfAbsent(input.key, { channelId: created, kickoff: input.kickoff })) {
    return created;
  }
  await input.destroy(created);
  return (await input.store.get(input.key))?.channelId ?? null;
}

/** How long a finished game's channel is kept after its first `end` push:
 *  the broadcast route's own `FINAL_EXPIRY_SECONDS`, because that is how
 *  long the stored `end` is worth delivering to a phone that was off. */
export const KEEP_AFTER_END_SECONDS = 3600;

/** A game that never produced an `end` (postponed, or it fell off the
 *  scoreboard across midnight) is reaped this long after kickoff. */
export const REAP_AFTER_KICKOFF_SECONDS = 24 * 3600;

/** Whether a stored channel is done with. */
export function isReapable(record: ChannelRecord, nowSeconds: number): boolean {
  if (record.endedAt !== undefined) {
    return nowSeconds - record.endedAt > KEEP_AFTER_END_SECONDS;
  }
  const kickoff = Date.parse(record.kickoff) / 1000;
  return Number.isFinite(kickoff) && nowSeconds - kickoff > REAP_AFTER_KICKOFF_SECONDS;
}

/** Only games starting within this window get a channel. ActivityKit ends
 *  a card after eight hours, so one pinned further out than this could
 *  never reach its kickoff anyway; the client starts a local card instead. */
export const PIN_AHEAD_LIMIT_SECONDS = 12 * 3600;

/** Whether a game may be given a channel: not over, and not too far off. */
export function acceptsChannel(
  game: { status: string; scheduledAt: string },
  phase: "pre" | "live" | "intermission" | "final",
  nowSeconds: number,
): boolean {
  if (phase === "final") return false;
  if (phase !== "pre") return true;
  const kickoff = Date.parse(game.scheduledAt) / 1000;
  return Number.isFinite(kickoff) && kickoff - nowSeconds <= PIN_AHEAD_LIMIT_SECONDS;
}
