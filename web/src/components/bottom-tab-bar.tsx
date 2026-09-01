"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { House, ListOrdered, Search, Shield } from "lucide-react";
import { cn } from "@/lib/utils";

const TABS = [
  { href: "/", label: "Scores", icon: House },
  { href: "/rankings", label: "Rankings", icon: ListOrdered },
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
