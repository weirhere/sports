"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { ChevronLeft } from "lucide-react";
import { cn } from "@/lib/utils";
import { Wordmark } from "@/components/wordmark";
import { GetTheAppPill } from "@/components/get-the-app";

const NAV_LINKS = [
  { href: "/", label: "Games" },
  { href: "/rankings", label: "Leagues" },
  { href: "/teams", label: "Teams" },
  { href: "/search", label: "Search" },
];

/**
 * The tabs. A page not in this set is a sub-page and gets the back chevron.
 *
 * It no longer carries titles. The bar used to swap the wordmark out for
 * the page's name on every screen but Scores — which spent the app's one
 * identity mark to say something two other controls were already saying
 * (the active nav link on desktop, the filled tab on a phone), and left the
 * mark itself visible on exactly one route. The mark is the constant now,
 * and each page names itself where a page should: `/rankings/poll` and
 * every entity page in their own hero, Leagues and Teams in a screen-reader
 * heading, since sighted users have the tab bar.
 */
const TOP_LEVEL_ROUTES = new Set(["/", "/rankings", "/teams", "/search"]);

export function NavBar() {
  const pathname = usePathname();
  const router = useRouter();
  const showBack = !TOP_LEVEL_ROUTES.has(pathname);

  return (
    <header className="sticky top-0 z-50 w-full bg-bg-primary">
      <div className="mx-auto flex h-14 max-w-[var(--page-max)] items-center px-4 sm:h-16">
        {/* The back chevron leads on a sub-page; the mark follows it there
            exactly as it leads everywhere else. */}
        {showBack && (
          <button
            type="button"
            onClick={() => router.back()}
            aria-label="Back"
            className="-ml-1 mr-3 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-bg-elevated transition-colors hover:bg-divider"
          >
            <ChevronLeft className="h-5 w-5 text-text-primary" />
          </button>
        )}

        {/* The mark, not a label, and no glyph beside it (iOS, 2026-09-09:
            a stock icon beside a stock system-font string reads as a
            placeholder logo). On every route, because a bar whose identity
            survives only on the home screen isn't an identity. */}
        <Link href="/" className="mr-6 flex items-center text-text-primary">
          <Wordmark />
        </Link>

        {/* Desktop nav */}
        <nav aria-label="Primary" className="hidden items-center gap-6 sm:flex">
          {NAV_LINKS.map((link) => {
            const active =
              link.href === "/"
                ? pathname === "/"
                : pathname.startsWith(link.href);
            return (
              <Link
                key={link.href}
                href={link.href}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "text-sm font-medium transition-colors hover:text-text-primary",
                  active ? "text-text-primary" : "text-text-secondary"
                )}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>

        {/* The one outbound link in the app, at every width — the nav bar's
            right slot has been empty since the Live pill and the funnel
            moved into the Scores control card (2026-09-10), and a bar that
            every page already carries is the only CTA placement that costs
            no vertical space. `ml-auto` pushes it there whether or not the
            desktop nav rendered. */}
        <GetTheAppPill />
      </div>
    </header>
  );
}
