"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { ChevronLeft, Settings } from "lucide-react";
import { cn } from "@/lib/utils";

const NAV_LINKS = [
  { href: "/", label: "Games" },
  { href: "/rankings", label: "Top 25" },
  { href: "/following", label: "Following" },
  { href: "/conferences", label: "Conferences" },
];

const TOP_LEVEL_PAGES = ["/", "/conferences", "/following", "/rankings", "/settings", "/search"];

function isTopLevel(pathname: string): boolean {
  return TOP_LEVEL_PAGES.includes(pathname);
}

export function NavBar() {
  const pathname = usePathname();
  const router = useRouter();
  const showBack = !isTopLevel(pathname);

  return (
    <header className="sticky top-0 z-50 w-full bg-background">
      <div className="mx-auto flex h-14 max-w-7xl items-center px-4 sm:h-16">
        {/* Back button on secondary pages, logo on top-level */}
        {showBack ? (
          <button
            type="button"
            onClick={() => router.back()}
            className="-ml-1 mr-3 flex h-8 w-8 items-center justify-center rounded-full bg-muted transition-colors hover:bg-accent"
          >
            <ChevronLeft className="h-5 w-5 text-foreground" />
          </button>
        ) : (
          <Link href="/" className="mr-6 flex items-center gap-2">
            <span className="text-2xl font-bold tracking-tight">
              {pathname === "/conferences"
                ? "Conferences"
                : pathname === "/following"
                  ? "Following"
                  : pathname === "/rankings"
                    ? "Top 25"
                    : pathname === "/settings"
                      ? "Settings"
                      : pathname === "/search"
                        ? "Search"
                        : "CFB Hub"}
            </span>
          </Link>
        )}

        {/* Desktop nav */}
        <nav className="hidden items-center gap-6 sm:flex">
          {NAV_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={cn(
                "text-sm font-medium transition-colors hover:text-foreground",
                (link.href === "/"
                  ? pathname === "/"
                  : pathname.startsWith(link.href))
                  ? "text-foreground"
                  : "text-muted-foreground"
              )}
            >
              {link.label}
            </Link>
          ))}
        </nav>

        {/* Right side */}
        <div className="ml-auto flex items-center gap-2">
          <div id="navbar-right-slot" />
          {pathname !== "/settings" && (
            <Link
              href="/settings"
              className="flex h-9 w-9 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
            >
              <Settings className="h-[18px] w-[18px]" />
              <span className="sr-only">Settings</span>
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}
