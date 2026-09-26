"use client";

// The Appearance choice — System, Light, Dark, System by default — the web
// twin of the iOS Settings sheet's segmented picker (`Appearance`,
// sports/Theme/Appearance.swift, 2026-09-25).
//
// **The theme needed no work.** Every token in `globals.css` already has a
// `.dark` twin, and `next-themes` has been writing that class from
// `prefers-color-scheme` since the web began; an override is the same class
// set from a stored choice instead. It is also flash-free as it comes:
// `next-themes` injects a blocking script ahead of first paint that reads
// the stored value and sets the class before any pixel of the wrong
// appearance draws. Stored per browser in localStorage (see the provider in
// `app/layout.tsx`), the web's `UserDefaults`.
//
// Monochrome as it comes, like iOS's segmented control: the selected
// segment is ink-filled, the same "on" language the Scores funnel uses.

import { useSyncExternalStore } from "react";
import { useTheme } from "next-themes";
import { cn } from "@/lib/utils";

const OPTIONS = [
  { value: "system", label: "System" },
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
] as const;

type Appearance = (typeof OPTIONS)[number]["value"];

function isAppearance(value: string | undefined): value is Appearance {
  return OPTIONS.some((option) => option.value === value);
}

const noSubscribe = () => () => {};

export function AppearancePicker({ className }: { className?: string }) {
  const { theme, setTheme } = useTheme();
  // The stored choice lives in the browser, so the server can't know it:
  // until hydration no segment claims to be selected, rather than the
  // server guessing "System" and the client correcting it a frame later.
  const isClient = useSyncExternalStore(
    noSubscribe,
    () => true,
    () => false
  );
  const selected: Appearance | undefined = isClient
    ? isAppearance(theme)
      ? theme
      : "system"
    : undefined;

  return (
    <div className={cn("flex items-center gap-3", className)}>
      <span
        id="appearance-label"
        className="type-meta-medium text-text-secondary"
      >
        Appearance
      </span>
      <div
        role="group"
        aria-labelledby="appearance-label"
        aria-describedby="appearance-hint"
        className="flex items-center gap-0.5 rounded-full bg-bg-card p-1 shadow-card"
      >
        {OPTIONS.map((option) => {
          const isOn = option.value === selected;
          return (
            <button
              key={option.value}
              type="button"
              onClick={() => setTheme(option.value)}
              aria-pressed={isOn}
              className={cn(
                "rounded-full px-3 py-1.5 type-meta-medium transition-colors",
                isOn
                  ? "bg-text-primary text-bg-primary"
                  : "text-text-primary hover:bg-bg-header"
              )}
            >
              {option.label}
            </button>
          );
        })}
      </div>
      {/* iOS's section footer, for the one reader who needs it spelled
          out; sighted users read "System" beside two explicit choices. */}
      <span id="appearance-hint" className="sr-only">
        System follows your device&rsquo;s Light or Dark setting.
      </span>
    </div>
  );
}
