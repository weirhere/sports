// The Games tab's re-tap — iOS `Router.scoresHomeCount` (2026-09-20,
// 2026-09-21).
//
// Clicking Games while already on Games takes the slate home: back to its top
// and back to today. The tab bar lives outside the Scores view, so the
// gesture travels the way iOS sends it, through a channel rather than a
// prop: a window event the view listens for.
//
// The wrinkle iOS doesn't have: the tab is a `next/link`, and a link to the
// route you're already on is a navigation the router treats as a no-op. So
// the re-tap is caught in the link's own onClick, by comparing the pathname
// before the router gets to short-circuit it.

import type { MouseEvent } from "react";

export const SCORES_HOME_EVENT = "statside:scores-home";

/** The Games route — the one tab whose re-tap means "home". */
export const SCORES_PATH = "/";

/**
 * Whether a click on a link to `href` is the Games re-tap: the Games link,
 * clicked from Games, as a plain primary click. A modified click (a new tab,
 * a new window) is the browser's and is left alone.
 */
export function isScoresRetap(
  href: string,
  pathname: string,
  event: Pick<
    MouseEvent,
    "button" | "metaKey" | "ctrlKey" | "shiftKey" | "altKey" | "defaultPrevented"
  >
): boolean {
  if (href !== SCORES_PATH || pathname !== SCORES_PATH) return false;
  if (event.defaultPrevented || event.button !== 0) return false;
  return !(event.metaKey || event.ctrlKey || event.shiftKey || event.altKey);
}

/** The link's onClick half: claim the re-tap and send the view home. */
export function handleScoresLinkClick(
  href: string,
  pathname: string,
  event: MouseEvent
): void {
  if (!isScoresRetap(href, pathname, event)) return;
  event.preventDefault();
  window.dispatchEvent(new Event(SCORES_HOME_EVENT));
}
