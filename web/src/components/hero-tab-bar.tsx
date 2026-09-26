"use client";

// The entity pages' hero tab row — iOS `HeroTabBar` (Theme/HeroTabBar.swift):
// 40px gap, 14px vertical padding, bold 14 labels at −2% tracking, and
// ink alone separating active from inactive (no underline — the 3pt bar
// retired 2026-08-31). Real tablist semantics: roving tabindex + arrow keys.
//
// Inactive tabs take `text-secondary`, not half-strength primary
// (2026-09-21). `#1a1a1a` at 50% composites to 3.34:1 on the white card —
// under AA's 4.5:1 for bold 14 — while dark measured 5.17:1, which is how
// it survived. The token is 5.33:1 light and 6.36:1 dark on `bg-card`.
//
// The row is its own horizontal scroller (2026-09-20). It was a bare flex
// row, so a five-tab team page on a narrow phone overflowed the document
// instead of itself and dragging the tabs slid the entire app — nav bar,
// hero, cards and all — sideways. Scrolling belongs to the strip; everything
// around it stays put.

import { useEffect, useRef } from "react";
import { cn } from "@/lib/utils";

export interface HeroTab {
  id: string;
  label: string;
}

interface HeroTabBarProps {
  tabs: HeroTab[];
  selected: string;
  onSelect: (id: string) => void;
}

/** Breathing room left beside a tab the strip had to scroll to reveal. */
const REVEAL_INSET = 16;

export function HeroTabBar({ tabs, selected, onSelect }: HeroTabBarProps) {
  const buttonsRef = useRef<Map<string, HTMLButtonElement>>(new Map());
  const scrollRef = useRef<HTMLDivElement>(null);
  // The first reveal jumps; every later one animates. A page that opens on a
  // tab halfway along the row shouldn't sweep past the eye on arrival.
  const hasScrolled = useRef(false);

  // Nearest-edge, not centred: five tabs are not a season of day chips, and
  // recentring the row under every tap moves labels the thumb is aiming at.
  useEffect(() => {
    const container = scrollRef.current;
    const button = buttonsRef.current.get(selected);
    if (!container || !button) return;

    const start = container.scrollLeft;
    const end = start + container.clientWidth;
    const behavior = hasScrolled.current ? "smooth" : "auto";
    hasScrolled.current = true;

    if (button.offsetLeft < start) {
      container.scrollTo({
        left: Math.max(0, button.offsetLeft - REVEAL_INSET),
        behavior,
      });
    } else if (button.offsetLeft + button.offsetWidth > end) {
      container.scrollTo({
        left:
          button.offsetLeft +
          button.offsetWidth +
          REVEAL_INSET -
          container.clientWidth,
        behavior,
      });
    }
  }, [selected, tabs.length]);

  const move = (from: string, delta: number) => {
    const index = tabs.findIndex((tab) => tab.id === from);
    if (index === -1) return;
    const next = tabs[(index + delta + tabs.length) % tabs.length];
    onSelect(next.id);
    buttonsRef.current.get(next.id)?.focus();
  };

  return (
    <div
      ref={scrollRef}
      role="tablist"
      // The gutter lives on the scroller, not its parent, so tabs scroll
      // out at the surface edge instead of being sliced off 16px short
      // of it. Callers hand it an unpadded surface.
      className="flex items-center gap-10 overflow-x-auto px-4 scrollbar-none"
    >
      {tabs.map((tab) => {
        const isSelected = tab.id === selected;
        return (
          <button
            key={tab.id}
            ref={(node) => {
              if (node) buttonsRef.current.set(tab.id, node);
              else buttonsRef.current.delete(tab.id);
            }}
            type="button"
            role="tab"
            id={`tab-${tab.id}`}
            aria-selected={isSelected}
            aria-controls={`panel-${tab.id}`}
            tabIndex={isSelected ? 0 : -1}
            onClick={() => onSelect(tab.id)}
            onKeyDown={(event) => {
              if (event.key === "ArrowRight") {
                event.preventDefault();
                move(tab.id, 1);
              } else if (event.key === "ArrowLeft") {
                event.preventDefault();
                move(tab.id, -1);
              }
            }}
            className={cn(
              // shrink-0: inside a scroller a flex label would otherwise
              // compress to its min-content width and wrap mid-word.
              "shrink-0 py-3.5 type-tab transition-colors",
              isSelected
                ? "text-text-primary"
                : "text-text-secondary hover:text-text-primary"
            )}
          >
            {tab.label}
          </button>
        );
      })}
    </div>
  );
}
