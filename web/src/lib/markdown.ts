// A markdown subset, parsed by hand.
//
// The two documents this renders — the privacy policy and the support page
// — are the only prose in the app, and the policy has to stay
// byte-identical to `PRIVACY.md` at the repo root (see
// `src/content/privacy.ts`). Rendering the markdown itself is what makes
// that equality possible: anything that transcribed the text into JSX
// would be a copy no test could hold.
//
// Hand-rolled because CLAUDE.md's Don'ts require an explicit conversation
// before a third-party package, and a parser for six block types is
// smaller than the argument for adding one. It is deliberately not a
// markdown implementation: it supports exactly what these two documents
// use, and anything else falls through as literal text rather than being
// silently swallowed.

export type Span =
  | { kind: "text"; text: string }
  | { kind: "strong"; text: string }
  | { kind: "link"; text: string; href: string };

export type Block =
  | { kind: "heading"; level: 1 | 2; spans: Span[] }
  /** A whole line in italics — the policy's effective date. Reads as a caption. */
  | { kind: "note"; spans: Span[] }
  | { kind: "paragraph"; spans: Span[] }
  | { kind: "list"; items: Span[][] };

// One alternation, so the three inline forms can't nest wrongly or race:
// a link's label is taken whole before `**` is looked for inside it, and a
// bare email is only an email when nothing else claimed those characters.
const INLINE =
  /\[([^\]]+)\]\(([^)\s]+)\)|\*\*([^*]+)\*\*|([\w.+-]+@[\w-]+\.[\w.-]*\w)/g;

/**
 * Inline spans for one line of markdown: `**bold**`, `[text](href)`, and a
 * bare email address, which becomes a `mailto:` link because an address
 * nobody can tap is a phone number written on a wall.
 */
export function parseInline(line: string): Span[] {
  const spans: Span[] = [];
  let last = 0;

  for (const match of line.matchAll(INLINE)) {
    const at = match.index;
    if (at > last) spans.push({ kind: "text", text: line.slice(last, at) });

    const [, linkText, href, strong, email] = match;
    if (href !== undefined) {
      spans.push({ kind: "link", text: linkText, href });
    } else if (strong !== undefined) {
      spans.push({ kind: "strong", text: strong });
    } else {
      spans.push({ kind: "link", text: email, href: `mailto:${email}` });
    }
    last = at + match[0].length;
  }

  if (last < line.length) spans.push({ kind: "text", text: line.slice(last) });
  return spans;
}

/**
 * Blocks for a whole document. Blank lines separate blocks; consecutive
 * `- ` lines are one list. A line is only a heading, a note or a bullet
 * when it opens as one — no continuation lines, because neither document
 * has any and guessing at them is how a parser this size starts lying.
 */
export function parseMarkdown(source: string): Block[] {
  const blocks: Block[] = [];
  let list: Span[][] | null = null;

  const closeList = () => {
    if (list) blocks.push({ kind: "list", items: list });
    list = null;
  };

  for (const raw of source.split("\n")) {
    const line = raw.trim();

    if (line === "") {
      closeList();
      continue;
    }

    if (line.startsWith("- ")) {
      (list ??= []).push(parseInline(line.slice(2)));
      continue;
    }
    closeList();

    const heading = /^(#{1,2})\s+(.*)$/.exec(line);
    if (heading) {
      blocks.push({
        kind: "heading",
        level: heading[1].length as 1 | 2,
        spans: parseInline(heading[2]),
      });
      continue;
    }

    // A whole line in italics, not a word inside one: `*…*` with no other
    // asterisks. `**bold**` at the head of a paragraph must not match.
    const note = /^\*([^*]+)\*$/.exec(line);
    if (note) {
      blocks.push({ kind: "note", spans: parseInline(note[1]) });
      continue;
    }

    blocks.push({ kind: "paragraph", spans: parseInline(line) });
  }

  closeList();
  return blocks;
}
