"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { CalendarDays, Medal, Heart, LayoutGrid, Search } from "lucide-react";
import { cn } from "@/lib/utils";

const TABS = [
  { href: "/", label: "Games", icon: CalendarDays },
  { href: "/rankings", label: "Top 25", icon: Medal },
  { href: "/following", label: "Following", icon: Heart },
  { href: "/conferences", label: "Conferences", icon: LayoutGrid },
  { href: "/search", label: "Search", icon: Search },
];

export function BottomTabBar() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 border-t bg-background pb-[env(safe-area-inset-bottom)] sm:hidden">
      <div className="flex">
        {TABS.map((tab) => {
          const active =
            tab.href === "/" ? pathname === "/" : pathname.startsWith(tab.href);
          const Icon = tab.icon;

          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={cn(
                "flex flex-1 flex-col items-center gap-0.5 py-2 text-[11px] font-medium transition-colors",
                active
                  ? "text-primary"
                  : "text-muted-foreground active:text-foreground"
              )}
            >
              <Icon className="h-5 w-5" />
              {tab.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
