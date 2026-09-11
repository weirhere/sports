// The typeface every OpenGraph card is set in.
//
// Inter stands in for SF Pro: Satori has no system fonts, and its built-in
// fallback ships one weight — which would flatten a card whose whole
// hierarchy is weight and size. Bundled rather than fetched over the
// network so rendering costs no hop and can't fail halfway.
//
// It lives beside the `.woff` files rather than in the route that draws
// the card, because `import.meta.url` resolves relative to *this* module:
// one copy of the path, however deep the route that asks for it.
//
// **Read from disk, not fetched.** The card shipped on 2026-09-09 asking
// for these files with `fetch(new URL(…, import.meta.url))` — the pattern
// Vercel's own OG examples use, which works because those examples run on
// the Edge runtime, where a bundled asset URL is an HTTP one. On the Node
// runtime that URL is a `file:`, and Node's fetch answers a `file:` with
// `TypeError: fetch failed` / "not implemented... yet...". So the loader
// took its own fallback path on every single render: the game card has
// been drawn in Satori's one-weight default font since the day it landed,
// which is why a winner's name never looked heavier than a loser's.
// `fs.readFile` takes the same file URL and actually reads it.

import { readFile } from "node:fs/promises";

// One static `new URL` per weight, never a template literal. A bundler
// resolves `new URL("./x", import.meta.url)` by *statically* matching the
// path against a file it can then emit; an interpolated path has nothing
// to match, so Turbopack falls back to the enclosing directory and hands
// back whichever asset it mapped first — this loader read the folder's
// LICENSE.txt as a typeface ("Unsupported OpenType signature Copy") and,
// in the arrangement before that, read one weight three times, which
// renders as a card with no weight hierarchy at all. Three literals cost
// three lines and cannot do either.
const FACES = [
  { url: new URL("./fonts/inter-latin-400-normal.woff", import.meta.url), weight: 400 as const },
  { url: new URL("./fonts/inter-latin-600-normal.woff", import.meta.url), weight: 600 as const },
  { url: new URL("./fonts/inter-latin-700-normal.woff", import.meta.url), weight: 700 as const },
];

/**
 * The three weights, or `undefined` when they couldn't be read.
 *
 * Undefined rather than a throw on purpose, and it is the same rule the
 * whole card is built on: an unfurler that gets a 500 shows **no image at
 * all**, and caches that nothing. A card in the fallback font beats no
 * card. That mercy is also what hid the `fetch` bug for every render since
 * the card shipped, so `fonts.test.ts` asserts the bytes are really a
 * font, and really three different ones.
 */
export async function interFonts() {
  try {
    return await Promise.all(
      FACES.map(async ({ url, weight }) => ({
        name: "Inter",
        weight,
        style: "normal" as const,
        data: await readFile(url),
      }))
    );
  } catch {
    return undefined;
  }
}
