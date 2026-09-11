// The ink an OpenGraph card is drawn in.
//
// Always the light values, with no dark twin: a link preview is rendered
// once on our server and then shown to everyone who sees the link, so the
// recipient's appearance setting is not ours to guess. A white card reads
// on any thread background; a dark one is a hole in a light one.
//
// Verbatim from `globals.css`'s `:root` block — these are the same tokens
// the app itself paints with, resolved to hex because Satori has no
// cascade to read a CSS variable from.

/** `--text-primary`: soft black, off true black (true black strains). */
export const INK = "#1a1a1a";
/** `--text-secondary`. */
export const MUTED = "#6b6b6b";
/** `--divider`. */
export const DIVIDER = "#e0e0e0";
/** `--bg-card` / `--bg-primary`: the card's own ground. */
export const PAPER = "#ffffff";
/** `--bg-recessed` / `--bg-elevated`: the page a card sits on, and the
 *  placeholder disc a logo that wouldn't load degrades to. */
export const RECESSED = "#ededed";
/** The app's one green: the live accent shares rank-up (2026-08-29). */
export const LIVE = "#008538";
