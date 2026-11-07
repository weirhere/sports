// A venue as an Apple Maps search (COR-151, 2026-11-07) — iOS `MapsLink`.
//
// ESPN gives a ground's name and city and no coordinates or address, so the
// link is a `q=` search: "Benchmark International Arena, Tampa, FL".
// maps.apple.com is the same link iOS opens, and it answers in any browser.

/** Undefined when there is no name to search for. */
export function mapsLink(name: string, city?: string): string | undefined {
  const place = name.trim();
  if (!place) return undefined;
  const town = city?.trim();
  const query = town ? `${place}, ${town}` : place;
  // encodeURIComponent escapes `&` (so "AT&T Stadium" survives) and also
  // `,`, which iOS leaves literal. Put commas back so both platforms build
  // the identical URL.
  return `https://maps.apple.com/?q=${encodeURIComponent(query).replace(/%2C/g, ",")}`;
}
