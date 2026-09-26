"use client";

// The React half of `lib/recent-searches` — iOS `RecentSearchesStore`'s
// observable surface. Lifetime and storage shapes are documented there.

import { useCallback, useEffect, useRef, useState } from "react";
import {
  RECENT_SEARCHES_KEY,
  readRecents,
  recordRecent,
  removeRecent,
  writeRecents,
  type RecentSearch,
} from "@/lib/recent-searches";

/** `localStorage`, or undefined where even touching it throws. */
function storage(): Storage | undefined {
  try {
    return typeof window === "undefined" ? undefined : window.localStorage;
  } catch {
    return undefined;
  }
}

export function useRecentSearches(): {
  entries: RecentSearch[];
  /** False until storage has been read, so the page can hold its empty
   *  state rather than flash it at someone who has recents. */
  isLoaded: boolean;
  record: (entry: RecentSearch) => void;
  remove: (entry: RecentSearch) => void;
} {
  const [entries, setEntries] = useState<RecentSearch[]>([]);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    // Read post-hydration on purpose, like the follow store: a lazy
    // initializer would diverge from the server-rendered markup.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setEntries(readRecents(storage()));
    setIsLoaded(true);

    // Another tab recorded or dismissed one — follow it, so two tabs of
    // the same browser don't overwrite each other's list on the next tap.
    const onStorage = (event: StorageEvent) => {
      if (event.key === RECENT_SEARCHES_KEY || event.key === null) {
        setEntries(readRecents(storage()));
      }
    };
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  // Read-modify-write against storage where there is some, so a list
  // another tab changed isn't overwritten with this tab's stale copy; the
  // in-memory list where there isn't. Written synchronously, in the event
  // handler, because a result tap records and navigates in one gesture and
  // the write must not wait on a render the navigation may pre-empt.
  const latest = useRef(entries);
  useEffect(() => {
    latest.current = entries;
  }, [entries]);

  const update = useCallback(
    (change: (list: readonly RecentSearch[]) => RecentSearch[]) => {
      const store = storage();
      const next = change(store ? readRecents(store) : latest.current);
      writeRecents(store, next);
      latest.current = next;
      setEntries(next);
    },
    []
  );

  const record = useCallback(
    (entry: RecentSearch) => update((list) => recordRecent(list, entry)),
    [update]
  );
  const remove = useCallback(
    (entry: RecentSearch) => update((list) => removeRecent(list, entry)),
    [update]
  );

  return { entries, isLoaded, record, remove };
}
