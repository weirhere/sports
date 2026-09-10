"use client";

// Renders fixed chrome **outside** the page-entrance animation.
//
// The route template animates the page in with framer-motion's `y`, and a
// `transform` on an ancestor makes that element the containing block for
// every `position: fixed` descendant. So for the length of the entrance the
// day strip anchored to the template div rather than the viewport and
// rendered *over* the slate — measured in a production build as
// `matrix(1, 0, 0, 1, 0, 8)` on the wrapper, with the strip's `top` resolving
// to 196px instead of 64.
//
// It settles correctly once the animation completes, which is why it read as
// a flash rather than a broken screen and went unnoticed through the whole
// 1.x life of the week strip.
//
// The target is the **app shell**, not `document.body`: the shell publishes
// `--page-max` as a custom property and the strip reads it to line up with
// the content, so portalling all the way to the body would fix the transform
// and break the width.

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";

export const CHROME_PORTAL_ID = "app-chrome-slot";

export function ChromePortal({ children }: { children: React.ReactNode }) {
  const [target, setTarget] = useState<HTMLElement | null>(null);

  useEffect(() => {
    // Resolved post-hydration — the same pattern the nav bar's own portal
    // uses, since the element doesn't exist during the server render.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setTarget(document.getElementById(CHROME_PORTAL_ID));
    return () => setTarget(null);
  }, []);

  // Before the target resolves the chrome simply isn't mounted — one frame,
  // and the alternative is rendering it into the transform it exists to
  // escape.
  if (target === null) return null;
  return createPortal(children, target);
}
