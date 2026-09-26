"use client";

// What the search list is narrowed to — iOS `SearchScopePills`
// (sports/Features/Search/SearchScopePills.swift, Andy, 2026-09-21, from
// FotMob). These replace the section headings the results used to carry: a
// heading names what you are looking at, a pill lets you ask for it.
//
// **It scrolls.** Five pills do not fit a narrow phone at this weight, and
// the hero tab row's lesson is that a fixed row of labels does not fail by
// truncating — it wraps, and a wrapped control row changes height under
// whatever sits below it. So the labels refuse to squeeze (`shrink-0`,
// `whitespace-nowrap`) and the overflow goes into a scroller with its own
// gutter.
//
// **Filled**, unlike the day strip's ink-only chips: a day is a position on
// an axis where one is always current, so weight alone reads; a scope is a
// filter that is on or off, and the app already paints that state on the
// Follow pill.

import { useEffect, useRef } from "react";
import { cn } from "@/lib/utils";

export const SEARCH_SCOPES = [
  "all",
  "teams",
  "players",
  "games",
  "conferences",
] as const;

export type SearchScope = (typeof SEARCH_SCOPES)[number];

const TITLES: Record<SearchScope, string> = {
  all: "All",
  teams: "Teams",
  players: "Players",
  games: "Games",
  conferences: "Conferences",
};

export function parseSearchScope(value: string | null | undefined): SearchScope {
  return SEARCH_SCOPES.find((scope) => scope === value) ?? "all";
}

export function SearchScopePills({
  selection,
  onSelect,
}: {
  selection: SearchScope;
  onSelect: (scope: SearchScope) => void;
}) {
  const selectedRef = useRef<HTMLButtonElement>(null);
  const hasMounted = useRef(false);

  // Keep the chosen pill in view — centred, as iOS does — but only after
  // first paint: a page that opens scrolled sideways reads as a glitch.
  useEffect(() => {
    if (!hasMounted.current) {
      hasMounted.current = true;
      return;
    }
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    selectedRef.current?.scrollIntoView({
      behavior: reduce ? "auto" : "smooth",
      block: "nearest",
      inline: "center",
    });
  }, [selection]);

  return (
    <div
      role="group"
      aria-label="Search scope"
      className="-mx-4 flex gap-2 overflow-x-auto px-4 py-2 scrollbar-none"
    >
      {SEARCH_SCOPES.map((scope) => {
        const selected = scope === selection;
        return (
          <button
            key={scope}
            ref={selected ? selectedRef : undefined}
            type="button"
            aria-pressed={selected}
            onClick={() => onSelect(scope)}
            className={cn(
              "min-h-[34px] shrink-0 whitespace-nowrap rounded-full px-3 py-2 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
              selected
                ? "bg-text-primary type-chip-em text-bg-primary"
                : "bg-bg-card type-chip text-text-secondary hover:text-text-primary"
            )}
          >
            {TITLES[scope]}
          </button>
        );
      })}
    </div>
  );
}
