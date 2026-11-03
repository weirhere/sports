// At most `limit` requests in flight; the rest wait their turn — iOS
// `RequestGate` (2026-11-03).
//
// A season fetch fans out to a request per day where a month comes back
// short, and college basketball's season is ~150 such days of ~2 MB each.
// Fired at once on iOS, 660 of 1,159 requests timed out with no byte
// received. Taken in turns they each finish.

/** How many of one season fetch's requests run at once. */
export const SEASON_REQUEST_LIMIT = 6;

export type RequestGate = <T>(operation: () => Promise<T>) => Promise<T>;

/**
 * A gate: call it with an operation and it runs once a slot is free,
 * retried once on failure — a request that failed under load usually
 * answers the second time, and one lost day would otherwise fail the
 * whole season.
 */
export function requestGate(limit: number): RequestGate {
  const width = Math.max(1, limit);
  let running = 0;
  const waiting: (() => void)[] = [];

  async function acquire(): Promise<void> {
    if (running < width) {
      running += 1;
      return;
    }
    await new Promise<void>((resolve) => waiting.push(resolve));
  }

  // Hands the slot straight to the next waiter, so `running` never drops
  // and refills between them.
  function release(): void {
    const next = waiting.shift();
    if (next) next();
    else running -= 1;
  }

  return async function run<T>(operation: () => Promise<T>): Promise<T> {
    await acquire();
    try {
      try {
        return await operation();
      } catch {
        return await operation();
      }
    } finally {
      release();
    }
  };
}
