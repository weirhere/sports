import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { PRIVACY_MARKDOWN } from "./privacy";

// The repo root, from this file — not from `process.cwd()`, which is `web/`
// under `npm test` and the repo root under some editors' runners.
const ROOT_POLICY = new URL("../../../PRIVACY.md", import.meta.url);

describe("the published policy and the repo's own", () => {
  it("are the same document, byte for byte", () => {
    // This is the whole mechanism. `PRIVACY.md` is the source of truth and
    // this is the copy the website serves, because Vercel builds with
    // `web/` as its root directory and a read reaching above it could fail
    // in production only. A copy is fine; a copy that can drift is not —
    // and drift is exactly what went wrong before. The page this replaces
    // sat in a second repo for seven weeks still claiming StatSide had "no
    // server of its own" and covered college football alone.
    //
    // If this fails: you edited one of the two. Copy `PRIVACY.md` into the
    // template literal in `privacy.ts`.
    expect(PRIVACY_MARKDOWN).toBe(readFileSync(ROOT_POLICY, "utf8"));
  });

  it("has a real effective date, not the drafting placeholder", () => {
    // It shipped as `[set on publication]` for seven weeks, because nothing
    // published it.
    expect(PRIVACY_MARKDOWN).not.toContain("[set on publication]");
    expect(PRIVACY_MARKDOWN).toMatch(
      /^\*Effective date: [A-Z][a-z]+ \d{1,2}, \d{4}\*$/m
    );
  });
});
