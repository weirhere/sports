"use client";

// The entity pages' hero tab row — iOS `HeroTabBar` (Theme/HeroTabBar.swift):
// 40px gap, 14px vertical padding, bold 14 labels at −2% tracking, and
// opacity alone separating active from inactive (no underline — the 3pt bar
// retired 2026-08-31). Real tablist semantics: roving tabindex + arrow keys.

import { useRef } from "react";
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

export function HeroTabBar({ tabs, selected, onSelect }: HeroTabBarProps) {
  const buttonsRef = useRef<Map<string, HTMLButtonElement>>(new Map());

  const move = (from: string, delta: number) => {
    const index = tabs.findIndex((tab) => tab.id === from);
    if (index === -1) return;
    const next = tabs[(index + delta + tabs.length) % tabs.length];
    onSelect(next.id);
    buttonsRef.current.get(next.id)?.focus();
  };

  return (
    <div role="tablist" className="flex items-center gap-10">
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
              "py-3.5 type-tab transition-opacity",
              isSelected
                ? "text-text-primary"
                : "text-text-primary opacity-50 hover:opacity-75"
            )}
          >
            {tab.label}
          </button>
        );
      })}
    </div>
  );
}
