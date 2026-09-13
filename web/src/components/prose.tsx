import Link from "next/link";
import { parseMarkdown, type Block, type Span } from "@/lib/markdown";

/**
 * The app's two prose documents, set in the app's own type.
 *
 * Every other screen in StatSide is a table, a row or a card, and its type
 * tokens are sized for that: 13pt rows, 10pt captions, nothing meant to be
 * read a paragraph at a time. So the body here is 15px on a relaxed
 * leading, with a measure capped by the card it sits in — the one place the
 * density target doesn't apply, because the density target is about
 * fitting a Saturday on a screen and this is about being read once.
 *
 * The headings still come from the shared tokens (`type-hero-title`,
 * `type-section-header-prominent`), so a policy page still reads as this
 * app and not as a legal document someone bolted on.
 */
export function Prose({ markdown }: { markdown: string }) {
  return (
    <div className="max-w-[38rem]">
      {parseMarkdown(markdown).map((block, i) => (
        <ProseBlock key={i} block={block} first={i === 0} />
      ))}
    </div>
  );
}

function ProseBlock({ block, first }: { block: Block; first: boolean }) {
  switch (block.kind) {
    case "heading":
      // An h1 opens the document and needs no top gap; an h2 is a new
      // section and gets a wide one, so the page's shape reads before a
      // word of it does.
      return block.level === 1 ? (
        <h1 className="type-hero-title text-text-primary">
          <Spans spans={block.spans} />
        </h1>
      ) : (
        <h2
          className={`type-section-header-prominent text-text-primary ${
            first ? "" : "mt-7"
          }`}
        >
          <Spans spans={block.spans} />
        </h2>
      );

    case "note":
      return (
        <p className="mt-1.5 type-meta text-text-secondary">
          <Spans spans={block.spans} />
        </p>
      );

    case "paragraph":
      return (
        <p
          className={`text-[15px] leading-relaxed text-text-primary ${
            first ? "" : "mt-3"
          }`}
        >
          <Spans spans={block.spans} />
        </p>
      );

    case "list":
      return (
        <ul className="mt-3 list-disc space-y-2 pl-5 text-[15px] leading-relaxed text-text-primary">
          {block.items.map((item, i) => (
            <li key={i}>
              <Spans spans={item} />
            </li>
          ))}
        </ul>
      );
  }
}

function Spans({ spans }: { spans: Span[] }) {
  return (
    <>
      {spans.map((span, i) => {
        if (span.kind === "strong") {
          return (
            <strong key={i} className="font-semibold">
              {span.text}
            </strong>
          );
        }
        if (span.kind === "link") {
          // An in-app path routes; a mailto: or an off-site URL is a plain
          // anchor. Underlined rather than coloured, because the colour
          // budget has three exceptions and a hyperlink isn't one of them.
          const className =
            "underline decoration-divider underline-offset-2 transition-colors hover:decoration-text-primary";
          return span.href.startsWith("/") ? (
            <Link key={i} href={span.href} className={className}>
              {span.text}
            </Link>
          ) : (
            <a key={i} href={span.href} className={className}>
              {span.text}
            </a>
          );
        }
        return <span key={i}>{span.text}</span>;
      })}
    </>
  );
}
