// Shared motion curves — the web's copies of the iOS `ScoresScreen`
// animation constants.

import type { Transition } from "framer-motion";

/**
 * Opening and closing sections — a tap, Hide all/Show all, and Expand all
 * alike: a 0.18s ease-out (iOS `accordionAnimation`, 2026-09-24). A default
 * spring's long settle is a drifting tail, and on a 40-row conference it
 * reads as lag rather than motion. The curve is SwiftUI's `.easeOut`
 * (Core Animation's ease-out control points).
 */
export const ACCORDION_TRANSITION: Transition = {
  duration: 0.18,
  ease: [0, 0, 0.58, 1],
};

/** Reduced motion: the height still changes, it just doesn't travel. */
export const INSTANT_TRANSITION: Transition = { duration: 0 };
