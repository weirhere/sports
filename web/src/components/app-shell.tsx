"use client";

import { usePathname } from "next/navigation";
import { NavBar } from "./nav-bar";
import { BottomTabBar } from "./bottom-tab-bar";
import { pageMaxWidth } from "@/lib/layout";

interface AppShellProps {
  children: React.ReactNode;
}

export function AppShell({ children }: AppShellProps) {
  // One width per route, published as a custom property so the nav bar and
  // the day strip line up with the content instead of each hardcoding a
  // number. Custom properties inherit through the tree, so the fixed week
  // strip inside <main> still sees it.
  const pathname = usePathname();

  return (
    <div
      className="min-h-screen"
      style={{ "--page-max": pageMaxWidth(pathname) } as React.CSSProperties}
    >
      <NavBar />
      <main className="mx-auto max-w-[var(--page-max)] px-4 pb-20 pt-3 sm:pb-6">
        {children}
      </main>
      <BottomTabBar />
    </div>
  );
}
