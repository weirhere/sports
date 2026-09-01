"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { ChevronLeft } from "lucide-react";
import { cn } from "@/lib/utils";

const NAV_LINKS = [
  { href: "/", label: "Scores" },
  { href: "/rankings", label: "Rankings" },
  { href: "/teams", label: "Teams" },
  { href: "/search", label: "Search" },
];

/** Top-level pages and their bar titles; "/" gets the wordmark instead. */
const TOP_LEVEL_TITLES: Record<string, string> = {
  "/": "StatSide",
  "/rankings": "Rankings",
  "/teams": "Teams",
  "/search": "Search",
};

/** Sub-pages that pair the back chevron with a bar title. */
const SUB_PAGE_TITLES: Record<string, string> = {
  "/rankings/poll": "Top 25",
};

export function NavBar() {
  const pathname = usePathname();
  const router = useRouter();
  const title = TOP_LEVEL_TITLES[pathname];
  const showBack = title === undefined;
  const subTitle = SUB_PAGE_TITLES[pathname];

  return (
    <header className="sticky top-0 z-50 w-full bg-bg-primary">
      <div className="mx-auto flex h-14 max-w-7xl items-center px-4 sm:h-16">
        {/* Back button on entity pages; wordmark or title on top-level */}
        {showBack ? (
          <>
            <button
              type="button"
              onClick={() => router.back()}
              aria-label="Back"
              className="-ml-1 mr-3 flex h-8 w-8 items-center justify-center rounded-full bg-bg-elevated transition-colors hover:bg-divider"
            >
              <ChevronLeft className="h-5 w-5 text-text-primary" />
            </button>
            {subTitle && (
              <span className="mr-6 text-[17px] font-bold tracking-tight">
                {subTitle}
              </span>
            )}
          </>
        ) : pathname === "/" ? (
          <Link href="/" className="mr-6 flex items-center gap-1.5">
            <span aria-hidden="true" className="text-[15px] leading-none">
              🏈
            </span>
            <span className="text-[17px] font-bold tracking-tight">
              StatSide
            </span>
          </Link>
        ) : (
          <span className="mr-6 text-[17px] font-bold tracking-tight">
            {title}
          </span>
        )}

        {/* Desktop nav */}
        <nav className="hidden items-center gap-6 sm:flex">
          {NAV_LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className={cn(
                "text-sm font-medium transition-colors hover:text-text-primary",
                (link.href === "/"
                  ? pathname === "/"
                  : pathname.startsWith(link.href))
                  ? "text-text-primary"
                  : "text-text-secondary"
              )}
            >
              {link.label}
            </Link>
          ))}
        </nav>

        {/* Right side */}
        <div className="ml-auto flex items-center gap-2">
          <div id="navbar-right-slot" />
        </div>
      </div>
    </header>
  );
}
