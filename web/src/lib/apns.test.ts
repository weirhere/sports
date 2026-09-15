import { describe, expect, it, beforeEach } from "vitest";
import { generateKeyPairSync } from "node:crypto";
import {
  apnsConfigFromEnv,
  broadcastHeaders,
  broadcastPayload,
  broadcastUrl,
  providerToken,
  resetApnsCaches,
  sendBroadcast,
  type ApnsConfig,
  type ApnsTransport,
} from "@/lib/apns";

/** A stand-in for the HTTP/2 transport. The real one is `http2Transport`,
 *  which needs a socket to Apple — these exercise everything around it. */
function transport(
  status: number,
  body = "",
  apnsId?: string,
): ApnsTransport {
  return async () => ({ status, body, apnsId });
}

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

beforeEach(() => resetApnsCaches());

describe("provider token", () => {
  it("is a three-part ES256 JWT naming the key and team", () => {
    const token = providerToken(config);
    const [header, claims, signature] = token.split(".");
    expect(signature).toBeTruthy();
    const decode = (part: string) =>
      JSON.parse(Buffer.from(part, "base64url").toString());
    expect(decode(header)).toEqual({ alg: "ES256", kid: "ABC1234567" });
    expect(decode(claims).iss).toBe("TEAM123456");
  });

  /** JOSE requires raw r||s, 64 bytes for P-256. Node signs DER, which is
   *  variable-length — get the conversion wrong and APNs rejects the token
   *  with a generic error that says nothing about why. */
  it("signs with a 64-byte raw signature, not DER", () => {
    const signature = providerToken(config).split(".")[2];
    expect(Buffer.from(signature, "base64url")).toHaveLength(64);
  });

  /** APNs rejects a provider that mints tokens too often, and the poll
   *  loop calls this once per live game per tick. */
  it("caches rather than re-signing on every call", () => {
    const first = providerToken(config, Date.UTC(2026, 8, 10, 12, 0, 0));
    const soon = providerToken(config, Date.UTC(2026, 8, 10, 12, 30, 0));
    expect(soon).toBe(first);
  });

  it("re-signs once the token is old enough to be refused", () => {
    const first = providerToken(config, Date.UTC(2026, 8, 10, 12, 0, 0));
    const later = providerToken(config, Date.UTC(2026, 8, 10, 13, 30, 0));
    expect(later).not.toBe(first);
  });
});

describe("broadcast request", () => {
  it("posts to the broadcasts path for the bare bundle id", () => {
    expect(broadcastUrl(config)).toBe(
      "https://api.sandbox.push.apple.com/4/broadcasts/apps/com.andyryanweir.sports",
    );
    expect(broadcastUrl({ ...config, environment: "production" })).toContain(
      "https://api.push.apple.com/",
    );
  });

  /** The topic carries the suffix; the path does not. Swapping them is the
   *  classic way to get a 400 out of APNs. */
  it("suffixes the topic but not the path", () => {
    const headers = broadcastHeaders(config, { channelId: "abc", contentState: {}, event: "update" });
    expect(headers["apns-topic"]).toBe("com.andyryanweir.sports.push-type.liveactivity");
    expect(broadcastUrl(config)).not.toContain("push-type");
    expect(headers["apns-push-type"]).toBe("liveactivity");
    expect(headers["apns-channel-id"]).toBe("abc");
  });

  it("wraps content-state in aps with an event and a timestamp", () => {
    const payload = broadcastPayload(
      { contentState: { phase: "live", headline: "Q3 5:24" }, event: "update", staleDate: 1_700_000_120 },
      1_700_000_000_000,
    );
    expect(payload).toEqual({
      aps: {
        timestamp: 1_700_000_000,
        event: "update",
        "content-state": { phase: "live", headline: "Q3 5:24" },
        "stale-date": 1_700_000_120,
      },
    });
  });

  it("surfaces APNs' reason string on failure rather than swallowing it", async () => {
    const result = await sendBroadcast(
      config,
      { channelId: "nope", contentState: {}, event: "update" },
      transport(400, JSON.stringify({ reason: "BadChannelId" }), "xyz"),
    );
    expect(result).toMatchObject({ ok: false, status: 400, reason: "BadChannelId", apnsId: "xyz" });
  });

  it("reports success without needing a body", async () => {
    const result = await sendBroadcast(
      config, { channelId: "abc", contentState: {}, event: "update" }, transport(200));
    expect(result.ok).toBe(true);
  });
});

describe("environment config", () => {
  it("is null until a provider key exists — the normal state today", () => {
    expect(apnsConfigFromEnv({} as NodeJS.ProcessEnv)).toBeNull();
  });

  /** Vercel env vars flatten newlines, and a PEM without them is not a PEM. */
  it("restores the newlines a dashboard-pasted PEM loses", () => {
    const resolved = apnsConfigFromEnv({
      APNS_KEY_ID: "K",
      APNS_TEAM_ID: "T",
      APNS_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----",
    } as unknown as NodeJS.ProcessEnv);
    expect(resolved?.privateKeyPem).toContain("\n");
    expect(resolved?.environment).toBe("sandbox");
  });
});

describe("a send that never reaches Apple", () => {
  // Found live 2026-09-15: a real broadcast against a real channel answered
  // HTTP 500 with an empty body. Signing happens inside `broadcastHeaders`,
  // `createPrivateKey` throws on a PEM it can't decode, and nothing caught
  // it — so the likeliest misconfiguration in the whole feature produced
  // the least debuggable possible response.
  const unreadable: ApnsConfig = {
    ...config,
    privateKeyPem: "-----BEGIN PRIVATE KEY-----not-a-key-----END PRIVATE KEY-----",
  };

  it("reports an unreadable key instead of throwing", async () => {
    const result = await sendBroadcast(unreadable, {
      channelId: "channel",
      contentState: {},
      event: "update",
    });

    expect(result.ok).toBe(false);
    // Status 0 because nothing was sent — there is no HTTP status to report.
    expect(result.status).toBe(0);
    expect(result.reason).toContain("apns-key-unreadable");
    // The reason names the variable and what to look at, because the person
    // reading it is looking at a dashboard rather than a stack trace.
    expect(result.reason).toContain("APNS_PRIVATE_KEY");
  });

  it("reports a transport failure the same way", async () => {
    const result = await sendBroadcast(
      config,
      { channelId: "channel", contentState: {}, event: "update" },
      async () => {
        throw new Error("getaddrinfo ENOTFOUND api.sandbox.push.apple.com");
      },
    );

    expect(result.ok).toBe(false);
    expect(result.status).toBe(0);
    expect(result.reason).toContain("apns-send-threw");
    expect(result.reason).toContain("ENOTFOUND");
  });

  // The failure that actually happened, 2026-09-15. Node's fetch speaks
  // HTTP/1.1 and APNs speaks HTTP/2, so undici fed binary frames to its
  // HTTP/1.1 parser. The transport is `node:http2` now; this pins that the
  // shape of that error still reports rather than escaping as a 500.
  it("reports the HTTP/1.1-parser failure that started all this", async () => {
    const result = await sendBroadcast(
      config,
      { channelId: "channel", contentState: {}, event: "update" },
      async () => {
        throw new TypeError("fetch failed");
      },
    );

    expect(result.ok).toBe(false);
    expect(result.status).toBe(0);
    expect(result.reason).toContain("apns-send-threw");
    expect(result.reason).toContain("fetch failed");
  });

  it("still returns APNs' own reason when Apple answers", async () => {
    const result = await sendBroadcast(
      config,
      { channelId: "channel", contentState: {}, event: "update" },
      transport(400, JSON.stringify({ reason: "BadDeviceToken" })),
    );

    // The catch must not swallow the case it was never meant to cover: a
    // send that reached Apple and was rejected still reports Apple's word.
    expect(result.ok).toBe(false);
    expect(result.status).toBe(400);
    expect(result.reason).toBe("BadDeviceToken");
  });
});
