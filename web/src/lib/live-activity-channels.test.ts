import { describe, expect, it } from "vitest";
import { channelKey, parseChannelMap, staticChannelDirectory } from "@/lib/live-activity-channels";

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
