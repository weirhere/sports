import { describe, expect, it } from "vitest";
import {
  KEEP_AFTER_END_SECONDS,
  PIN_AHEAD_LIMIT_SECONDS,
  REAP_AFTER_KICKOFF_SECONDS,
  acceptsChannel,
  channelKey,
  ensureChannel,
  isReapable,
  kvChannelStore,
  memoryChannelStore,
  parseChannelMap,
  staticChannelDirectory,
} from "@/lib/live-activity-channels";
import type { Kv } from "@/lib/kv";

describe("channel map", () => {
  it("keys by league and game, because ESPN ids collide across leagues", () => {
    // 5 is UAB in college football and the Browns in the NFL — the same
    // collision FollowKey and TeamRef already exist to survive.
    expect(channelKey("5", "cfb")).not.toBe(channelKey("5", "nfl"));
  });

  it("reads a JSON object of channel ids", () => {
    expect(parseChannelMap('{"cfb:401":"abc"}')).toEqual({ "cfb:401": "abc" });
  });

  /** A bad env var should degrade to "no channel", never take the route down. */
  it("degrades to empty on anything malformed", () => {
    expect(parseChannelMap(undefined)).toEqual({});
    expect(parseChannelMap("not json")).toEqual({});
    expect(parseChannelMap("[1,2]")).toEqual({});
    expect(parseChannelMap('{"cfb:401":42}')).toEqual({});
  });

  it("answers null for a game with no channel", async () => {
    const directory = staticChannelDirectory({
      APNS_CHANNELS: '{"cfb:401":"abc"}',
    } as unknown as NodeJS.ProcessEnv);
    expect(await directory.channelId("401", "cfb")).toBe("abc");
    expect(await directory.channelId("999", "cfb")).toBeNull();
    expect(await directory.channelId("401", "nfl")).toBeNull();
  });
});

describe("channels on demand (2026-09-24)", () => {
  const kickoff = "2026-09-26T19:30:00Z";
  const kickoffSeconds = Date.parse(kickoff) / 1000;

  it("makes a game's channel once, then reads it back", async () => {
    const store = memoryChannelStore();
    let made = 0;
    const input = {
      store,
      key: "cfb:401",
      kickoff,
      create: async () => `ch${++made}`,
      destroy: async () => {},
    };
    expect(await ensureChannel(input)).toBe("ch1");
    expect(await ensureChannel(input)).toBe("ch1");
    expect(made).toBe(1);
  });

  it("gives a racing pin the winner's channel and deletes its own", async () => {
    const store = memoryChannelStore();
    const destroyed: string[] = [];
    // The other pin lands between this one's create and its write.
    const result = await ensureChannel({
      store,
      key: "cfb:401",
      kickoff,
      create: async () => {
        await store.putIfAbsent("cfb:401", { channelId: "winner", kickoff });
        return "loser";
      },
      destroy: async (id) => {
        destroyed.push(id);
      },
    });
    expect(result).toBe("winner");
    expect(destroyed).toEqual(["loser"]);
  });

  it("makes nothing when Apple wouldn't", async () => {
    const store = memoryChannelStore();
    const result = await ensureChannel({
      store, key: "cfb:401", kickoff, create: async () => null, destroy: async () => {},
    });
    expect(result).toBeNull();
    expect(store.data.size).toBe(0);
  });

  it("keeps a finished game's channel for an hour after its first end", () => {
    const record = { channelId: "c", kickoff, endedAt: 1_000_000 };
    expect(isReapable(record, 1_000_000 + KEEP_AFTER_END_SECONDS)).toBe(false);
    expect(isReapable(record, 1_000_000 + KEEP_AFTER_END_SECONDS + 1)).toBe(true);
  });

  it("reaps a game that never ended a day after its kickoff", () => {
    const record = { channelId: "c", kickoff };
    expect(isReapable(record, kickoffSeconds + 3600)).toBe(false);
    expect(isReapable(record, kickoffSeconds + REAP_AFTER_KICKOFF_SECONDS + 1)).toBe(true);
  });

  it("gives channels to live games and to kickoffs within twelve hours", () => {
    const game = { status: "scheduled", scheduledAt: kickoff };
    expect(acceptsChannel(game, "pre", kickoffSeconds - 3600)).toBe(true);
    expect(acceptsChannel(game, "pre", kickoffSeconds - PIN_AHEAD_LIMIT_SECONDS - 1)).toBe(false);
    expect(acceptsChannel({ ...game, status: "in_progress" }, "live", kickoffSeconds + 60)).toBe(true);
    expect(acceptsChannel({ ...game, status: "complete" }, "final", kickoffSeconds + 60)).toBe(false);
  });
});

describe("the kv store", () => {
  function fakeKv(answers: Record<string, unknown> = {}) {
    const calls: (string | number)[][] = [];
    const kv: Kv = {
      async command<T>(args: (string | number)[]) {
        calls.push(args);
        return answers[String(args[0])] as T;
      },
    };
    return { kv, calls };
  }

  it("writes with NX and an expiry, and reports who won", async () => {
    const { kv, calls } = fakeKv({ SET: "OK" });
    const won = await kvChannelStore(kv).putIfAbsent("cfb:401", { channelId: "c", kickoff: "k" });
    expect(won).toBe(true);
    expect(calls[0].slice(0, 2)).toEqual(["SET", "la:ch:cfb:401"]);
    expect(calls[0]).toContain("NX");
    expect(calls[0]).toContain("EX");

    const lost = fakeKv({ SET: null });
    expect(await kvChannelStore(lost.kv).putIfAbsent("cfb:401", { channelId: "c", kickoff: "k" }))
      .toBe(false);
  });

  it("lists every record, dropping unreadable ones", async () => {
    const { kv } = fakeKv({
      SCAN: ["0", ["la:ch:cfb:401", "la:ch:nfl:9"]],
      MGET: ['{"channelId":"c","kickoff":"k"}', "garbage"],
    });
    expect(await kvChannelStore(kv).entries()).toEqual([
      ["cfb:401", { channelId: "c", kickoff: "k", endedAt: undefined }],
    ]);
  });
});
