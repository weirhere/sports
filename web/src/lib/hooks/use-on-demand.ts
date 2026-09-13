"use client";

import { useCallback, useEffect, useRef, useState } from "react";

/**
 * What a tab that fetches its own data has to show.
 *
 * The distinction that matters is the last two: an empty answer and a failed
 * fetch look identical on screen, and only one of them gets to say "no
 * meetings" or "no titles".
 */
export type OnDemand<T> =
  | { status: "loading" }
  | { status: "failed" }
  | { status: "loaded"; value: T };

/**
 * Fetch something the first time a tab asks for it, and never again.
 *
 * Two panes need this and both need it for the same reason: a head-to-head
 * series and a trophy case are each a walk over a dozen seasons, so the page
 * they hang off must not pay for them on every visit. `key` is undefined until
 * the tab has been opened — and stays defined afterwards, so flipping back to
 * a tab already fetched costs nothing.
 *
 * It is also the identity: an answer is only ever shown under the key it was
 * fetched for, so a key that changes reads as loading rather than leaving the
 * last subject's series under this one's crests. That is why the key rides the
 * stored result instead of a reset in the effect — the state is derived, not
 * cleared.
 */
export function useOnDemand<T>(
  key: string | undefined,
  load: (key: string) => Promise<T>
): { state: OnDemand<T>; reload: () => void } {
  const [attempt, setAttempt] = useState(0);
  const [result, setResult] = useState<{
    key: string;
    attempt: number;
    state: OnDemand<T>;
  }>();
  // Held in a ref so a caller's inline arrow doesn't count as a new subject —
  // the key is what says the subject changed.
  const loadRef = useRef(load);
  useEffect(() => {
    loadRef.current = load;
  });

  useEffect(() => {
    if (key === undefined) return;
    let cancelled = false;
    loadRef
      .current(key)
      .then((value) => {
        if (!cancelled) {
          setResult({ key, attempt, state: { status: "loaded", value } });
        }
      })
      .catch(() => {
        if (!cancelled) setResult({ key, attempt, state: { status: "failed" } });
      });
    return () => {
      cancelled = true;
    };
  }, [key, attempt]);

  const state: OnDemand<T> =
    result !== undefined && result.key === key && result.attempt === attempt
      ? result.state
      : { status: "loading" };

  return {
    state,
    reload: useCallback(() => setAttempt((count) => count + 1), []),
  };
}
