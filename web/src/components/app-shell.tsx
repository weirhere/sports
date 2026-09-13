"use client";

import { NavBar } from "./nav-bar";
import { BottomTabBar } from "./bottom-tab-bar";
import { SiteFooter } from "./site-footer";
import { PAGE_MAX } from "@/lib/layout";
import { CHROME_PORTAL_ID } from "./chrome-portal";

interface AppShellProps {
  children: React.ReactNode;
}

export function AppShell({ children }: AppShellProps) {
  // One width for the whole app, published as a custom property so the nav
  // bar lines up with the content instead of hardcoding a number of its
  // own. Custom properties inherit through the tree, so anything nested in
  // <main> still sees it. It was a width *per route* until 2026-09-10,
  // which is what made the chrome jump sideways on every tab change.
  return (
    <div
      className="min-h-screen"
      style={{ "--page-max": PAGE_MAX } as React.CSSProperties}
    >
      <NavBar />
      {/* Fixed chrome mounts here rather than inside the page, which the
          route template transforms on entry — a transformed ancestor becomes
          the containing block for every `position: fixed` descendant. */}
      <div id={CHROME_PORTAL_ID} />
      <main className="mx-auto max-w-[var(--page-max)] px-4 pt-3">
        {children}
      </main>
      {/* The bottom padding that clears the fixed tab bar lives on the
          footer now, not on <main>: with it still on the content, every
          route showed 80px of dead space between its last card and the
          hairline above the footer. */}
      <SiteFooter />
      <BottomTabBar />
    </div>
  );
}
