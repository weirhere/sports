// Fetching a mark for a card Satori is about to draw.
//
// Satori fetches remote images itself and **throws** when one won't load,
// so a cold ESPN CDN would take the whole card down with it — and an
// unfurler that gets a 500 shows no image at all, then caches that
// nothing. Fetching here turns a dead mark into a quiet placeholder disc,
// which is the app's own rule for the same gap.

/** A data: URL Satori can draw without a request of its own, or null. */
export async function logoData(url: string | undefined): Promise<string | null> {
  if (!url) return null;
  try {
    const res = await fetch(url, {
      signal: AbortSignal.timeout(2000),
      next: { revalidate: 86400 },
    });
    if (!res.ok) return null;
    const buffer = Buffer.from(await res.arrayBuffer());
    const type = res.headers.get("content-type") ?? "image/png";
    return `data:${type};base64,${buffer.toString("base64")}`;
  } catch {
    return null;
  }
}
