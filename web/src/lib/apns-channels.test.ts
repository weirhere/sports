import { describe, expect, it, beforeEach } from "vitest";
import { generateKeyPairSync } from "node:crypto";
import {
  channelsUrl,
  createChannel,
  deleteChannel,
  resetApnsCaches,
  type ApnsConfig,
  type ApnsTransport,
} from "@/lib/apns";

// Channel management (2026-09-24, E12 blocker 3): creating a game's
// broadcast channel on its first pin, and deleting it once the game is over.

const { privateKey } = generateKeyPairSync("ec", {
  namedCurve: "P-256",
  privateKeyEncoding: { type: "pkcs8", format: "pem" },
  publicKeyEncoding: { type: "spki", format: "pem" },
});

const config: ApnsConfig = {
  keyId: "ABC1234567",
  teamId: "TEAM123456",
  privateKeyPem: privateKey as string,
  bundleId: "com.andyryanweir.sports",
  environment: "sandbox",
};

interface Call {
  url: string;
  headers: Record<string, string>;
  body: string;
  method?: string;
}

function recording(result: Awaited<ReturnType<ApnsTransport>>) {
  const calls: Call[] = [];
  const transport: ApnsTransport = async (url, headers, body, method) => {
    calls.push({ url, headers, body, method });
    return result;
  };
  return { calls, transport };
}

beforeEach(() => resetApnsCaches());

describe("the management host", () => {
  // Apple's docs, checked 2026-09-24: the two environments are on
  // different ports, and the service doc had said :2196 for both.
  it("is :2195 in the sandbox and :2196 in production", () => {
    expect(channelsUrl(config)).toBe(
      "https://api-manage-broadcast.sandbox.push.apple.com:2195/1/apps/com.andyryanweir.sports/channels",
    );
    expect(channelsUrl({ ...config, environment: "production" })).toBe(
      "https://api-manage-broadcast.push.apple.com:2196/1/apps/com.andyryanweir.sports/channels",
    );
  });
});

describe("creating a channel", () => {
  it("POSTs a Live Activity channel that keeps its most recent message", async () => {
    const { calls, transport } = recording({ status: 201, body: "", channelId: "Y2hhbm5lbA==" });
    const result = await createChannel(config, transport);
    expect(result).toEqual({ ok: true, status: 201, channelId: "Y2hhbm5lbA==" });
    expect(calls[0].method).toBe("POST");
    expect(JSON.parse(calls[0].body)).toEqual({
      "message-storage-policy": 1,
      "push-type": "LiveActivity",
    });
    expect(calls[0].headers.authorization).toMatch(/^bearer /);
  });

  it("is a failure when Apple answers 201 with no id", async () => {
    const { transport } = recording({ status: 201, body: "" });
    expect(await createChannel(config, transport)).toEqual({
      ok: false,
      status: 201,
      reason: "no-channel-id-header",
    });
  });

  it("surfaces Apple's reason", async () => {
    const { transport } = recording({ status: 403, body: '{"reason":"InvalidProviderToken"}' });
    const result = await createChannel(config, transport);
    expect(result.ok).toBe(false);
    expect(result.reason).toBe("InvalidProviderToken");
  });

  it("reports a transport that throws instead of throwing", async () => {
    const transport: ApnsTransport = async () => {
      throw new Error("connect ECONNREFUSED");
    };
    const result = await createChannel(config, transport);
    expect(result).toMatchObject({ ok: false, status: 0 });
    expect(result.reason).toContain("ECONNREFUSED");
  });
});

describe("deleting a channel", () => {
  it("DELETEs by the channel id header", async () => {
    const { calls, transport } = recording({ status: 204, body: "" });
    expect(await deleteChannel(config, "abc", transport)).toEqual({ ok: true, status: 204 });
    expect(calls[0].method).toBe("DELETE");
    expect(calls[0].headers["apns-channel-id"]).toBe("abc");
  });
});
