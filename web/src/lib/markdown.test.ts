import { describe, expect, it } from "vitest";
import { parseInline, parseMarkdown } from "./markdown";
import { PRIVACY_MARKDOWN } from "@/content/privacy";
import { SUPPORT_MARKDOWN } from "@/content/support";

describe("inline spans", () => {
  it("makes a bare email address tappable", () => {
    // The contact line in both documents is a bare address. A support page
    // whose email can't be tapped is a phone number written on a wall.
    expect(parseInline("Questions: a.b+c@example.co.uk")).toEqual([
      { kind: "text", text: "Questions: " },
      {
        kind: "link",
        text: "a.b+c@example.co.uk",
        href: "mailto:a.b+c@example.co.uk",
      },
    ]);
  });

  it("does not swallow a trailing period into the address", () => {
    const spans = parseInline("Email me@example.com.");
    expect(spans.at(-1)).toEqual({ kind: "text", text: "." });
  });

  it("reads a link's label whole, before anything inside it", () => {
    expect(parseInline("the [privacy policy](/privacy) is the long version"))
      .toEqual([
        { kind: "text", text: "the " },
        { kind: "link", text: "privacy policy", href: "/privacy" },
        { kind: "text", text: " is the long version" },
      ]);
  });

  it("emphasises **bold** and leaves the asterisks out of the text", () => {
    expect(parseInline("stored **only on your device** (and backups)")).toEqual([
      { kind: "text", text: "stored " },
      { kind: "strong", text: "only on your device" },
      { kind: "text", text: " (and backups)" },
    ]);
  });
});

describe("blocks", () => {
  it("separates heading levels", () => {
    const blocks = parseMarkdown("# Title\n\n## Section\n\nBody.");
    expect(blocks.map((b) => b.kind)).toEqual([
      "heading",
      "heading",
      "paragraph",
    ]);
    expect(blocks[0]).toMatchObject({ level: 1 });
    expect(blocks[1]).toMatchObject({ level: 2 });
  });

  it("gathers consecutive bullets into one list, and closes it", () => {
    const blocks = parseMarkdown("- one\n- two\n\nAfter.");
    expect(blocks).toHaveLength(2);
    expect(blocks[0]).toMatchObject({ kind: "list" });
    expect(blocks[0]).toHaveProperty("items.length", 2);
    expect(blocks[1]).toMatchObject({ kind: "paragraph" });
  });

  it("treats a whole italic line as a note but a bold opener as prose", () => {
    // `*Effective date: …*` is the policy's caption; `**Nothing.** StatSide
    // has no accounts…` is a paragraph that happens to start bold. One
    // asterisk rule has to tell them apart.
    const [note, paragraph] = parseMarkdown(
      "*Effective date: September 13, 2026*\n\n**Nothing.** No accounts."
    );
    expect(note.kind).toBe("note");
    expect(paragraph.kind).toBe("paragraph");
  });
});

describe("the documents the app actually ships", () => {
  for (const [name, markdown] of [
    ["the privacy policy", PRIVACY_MARKDOWN],
    ["the support page", SUPPORT_MARKDOWN],
  ] as const) {
    it(`${name} opens with its own h1`, () => {
      expect(parseMarkdown(markdown)[0]).toMatchObject({
        kind: "heading",
        level: 1,
      });
    });

    it(`${name} leaves no markup rendering as literal text`, () => {
      // The renderer prints a text span verbatim, so an unsupported form
      // would reach the page as asterisks and brackets. This is the check
      // that a hand-rolled subset is still a superset of these two files.
      const literal = parseMarkdown(markdown)
        .flatMap((block) =>
          block.kind === "list" ? block.items.flat() : block.spans
        )
        .filter((span) => span.kind === "text")
        .map((span) => span.text)
        .join("");
      expect(literal).not.toMatch(/\*|\[|\]\(|^#|_[a-z]/);
    });

    it(`${name} carries a contact address`, () => {
      const links = parseMarkdown(markdown)
        .flatMap((block) =>
          block.kind === "list" ? block.items.flat() : block.spans
        )
        .filter((span) => span.kind === "link");
      expect(links.some((l) => l.href.startsWith("mailto:"))).toBe(true);
    });
  }
});
