"use client";

import { useCallback, useEffect, useState } from "react";

/**
 * How the game page's Starters section draws its lineups: on the painted
 * field, or as the two-column list cards the rest of the Roster tab is made
 * of (iOS `StartersLayout`, Andy, 2026-10-18 — "some users might not like
 * this visualization and just want to see a card with a list of all the
 * players"). One preference for every league; the control that sets it
 * lives on the section itself, where you are looking when you decide. The
 * value is `field` whatever the sport; the chip says what the sport calls
 * it (Field, Court, Rink).
 */
export type StartersLayout = "field" | "list";

/** The iOS key, so the ledger can say "the same key" and mean it. */
const STORAGE_KEY = "ui.startersLayout";

function parse(raw: string | null): StartersLayout {
  return raw === "list" ? "list" : "field";
}

export function useStartersLayout(): [StartersLayout, (layout: StartersLayout) => void] {
  const [layout, setLayout] = useState<StartersLayout>("field");

  useEffect(() => {
    // Read post-hydration on purpose (the use-ui-state pattern): a lazy
    // initializer would diverge from the server-rendered markup.
    try {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setLayout(parse(localStorage.getItem(STORAGE_KEY)));
    } catch {
      // Storage unavailable — the default stands.
    }
  }, []);

  const update = useCallback((next: StartersLayout) => {
    setLayout(next);
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // In-memory state still updates.
    }
  }, []);

  return [layout, update];
}
