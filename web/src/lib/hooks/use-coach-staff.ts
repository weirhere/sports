"use client";

import { useEffect, useState } from "react";

// `public/coaches.json`, fetched once per page load and shared by every
// caller. A miss is silent: the Coaches card then lists the head coach the
// roster payload named and nothing more.
let pending: Promise<unknown> | undefined;

function loadCoachesFile(): Promise<unknown> {
  pending ??= fetch("/coaches.json")
    .then((res) => (res.ok ? res.json() : undefined))
    .catch(() => undefined);
  return pending;
}

/** The parsed coaches file, or undefined until it lands (or when it won't). */
export function useCoachStaffFile(): unknown {
  const [file, setFile] = useState<unknown>(undefined);
  useEffect(() => {
    let cancelled = false;
    void loadCoachesFile().then((loaded) => {
      if (!cancelled) setFile(loaded);
    });
    return () => {
      cancelled = true;
    };
  }, []);
  return file;
}
