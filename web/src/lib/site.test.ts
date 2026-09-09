import { afterEach, describe, expect, it } from "vitest";
import { PRODUCTION_ORIGIN, siteOrigin } from "./site";

const KEYS = ["NEXT_PUBLIC_SITE_URL", "VERCEL_ENV", "VERCEL_URL"] as const;
const saved = Object.fromEntries(KEYS.map((k) => [k, process.env[k]]));

afterEach(() => {
  for (const key of KEYS) {
    if (saved[key] === undefined) delete process.env[key];
    else process.env[key] = saved[key];
  }
});

describe("the origin absolute metadata is built against", () => {
  it("is the domain on a production deploy, never the vercel.app one", () => {
    // VERCEL_URL is set on production deploys too, and holds the
    // deployment's own hostname — trusting it would publish every
    // canonical URL and og:image under a host nobody recognises.
    process.env.VERCEL_ENV = "production";
    process.env.VERCEL_URL = "sports-abc123.vercel.app";
    delete process.env.NEXT_PUBLIC_SITE_URL;
    expect(siteOrigin()).toBe(PRODUCTION_ORIGIN);
  });

  it("is the preview's own URL on a preview deploy", () => {
    process.env.VERCEL_ENV = "preview";
    process.env.VERCEL_URL = "sports-abc123.vercel.app";
    delete process.env.NEXT_PUBLIC_SITE_URL;
    expect(siteOrigin()).toBe("https://sports-abc123.vercel.app");
  });

  it("lets an explicit override win, trailing slash and all", () => {
    process.env.VERCEL_ENV = "production";
    process.env.NEXT_PUBLIC_SITE_URL = "https://staging.statside.co/";
    expect(siteOrigin()).toBe("https://staging.statside.co");
  });
});
