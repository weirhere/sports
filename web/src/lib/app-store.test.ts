import { describe, expect, it } from "vitest";
import { APP_STORE_APP_ID, APP_STORE_URL } from "./app-store";

describe("the App Store link the download CTAs share", () => {
  it("names the same app the Smart App Banner does", () => {
    // The two reach the store by different routes — an `<a href>` and
    // Safari's `<meta name="apple-itunes-app" content="app-id=…">` — and
    // nothing in the browser cross-checks them. A link edited to a literal
    // (Apple's web UI hands you the `/us/app/statside-sports/id…` form)
    // would silently leave the banner pointing at the old id.
    expect(APP_STORE_URL).toContain(`id${APP_STORE_APP_ID}`);
  });

  it("is storefront-agnostic, so a link shared abroad still resolves", () => {
    // `/us/` pins the US storefront. The bare form lets Apple route each
    // visitor to their own — and it is the form the iOS app's own shares
    // have carried since 1.0 (`ShareSignOff.appStoreLink`).
    expect(new URL(APP_STORE_URL).pathname).toBe(`/app/id${APP_STORE_APP_ID}`);
  });

  it("carries no campaign parameters", () => {
    // The app takes no analytics (CLAUDE.md, v1). A `pt`/`ct` token here
    // would be the first, and it would ride every shared link.
    expect(new URL(APP_STORE_URL).search).toBe("");
  });

  it("is an app id, not a slug", () => {
    // `content="app-id=statside"` renders no banner at all, silently.
    expect(APP_STORE_APP_ID).toMatch(/^\d+$/);
  });
});
