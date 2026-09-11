"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { House, Search, Shield, Trophy } from "lucide-react";
import { cn } from "@/lib/utils";

const TABS = [
  // "Games", not "Scores" (iOS `RootView`, which has labelled this tab
  // Games since the league axis landed): the tab is the whole slate, and a
  // slate at 11am on a Saturday has no scores in it at all. The route, the
  // view and every `scores*` symbol keep their names — only the word moved,
  // exactly as the Tables → Leagues rename did.
  { href: "/", label: "Games", icon: House },
  // "Leagues", not "Rankings" (iOS, 2026-09-09): what the hub lists is
  // leagues, and a conference or a poll is reached *through* one. The
  // trophy replaced a numbered-list glyph that drew the standings table the
  // old name promised. The route keeps its name; only the words moved.
  { href: "/rankings", label: "Leagues", icon: Trophy },
  { href: "/teams", label: "Teams", icon: Shield },
  { href: "/search", label: "Search", icon: Search },
];

export function BottomTabBar() {
  const pathname = usePathname();

  return (
    <nav
      aria-label="Primary"
      className="fixed bottom-0 left-0 right-0 z-50 border-t border-divider bg-bg-primary pb-[env(safe-area-inset-bottom)] sm:hidden"
    >
      <div className="flex">
        {TABS.map((tab) => {
          const active =
            tab.href === "/" ? pathname === "/" : pathname.startsWith(tab.href);
          const Icon = tab.icon;

          return (
            <Link
              key={tab.href}
              href={tab.href}
              aria-current={active ? "page" : undefined}
              className={cn(
                "flex flex-1 flex-col items-center gap-0.5 py-2 type-row-meta-medium transition-colors",
                active
                  ? "text-text-primary"
                  : "text-text-secondary active:text-text-primary"
              )}
            >
              <Icon aria-hidden="true" className="h-5 w-5" />
              {tab.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
