"use client";

// One collapsible section of the scores list — the iOS `SectionAccordion`
// (sports/Features/Scores/SectionAccordion.swift): bg-header header row,
// hairline-divided game rows when expanded. Replaces the old day-group /
// conference-group / my-teams-section trio with one component fed by the
// game-sections engine.

import Link from "next/link";
import { Calendar, ChevronDown, Star, Trophy } from "lucide-react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import type { GameSection } from "@/lib/game-sections";
import { GameRow } from "./game-row";
import { ConferenceLogo } from "./theme/conference-logo";
import { cn } from "@/lib/utils";

interface SectionAccordionProps {
  section: GameSection;
  isExpanded: boolean;
  onToggle: () => void;
  /**
   * Date grouping: the day header pins below the app header/week strip
   * while its games scroll, keeping the card's floating top edge.
   */
  pinsHeader?: boolean;
}

export function SectionAccordion({
  section,
  isExpanded,
  onToggle,
  pinsHeader = false,
}: SectionAccordionProps) {
  const reducedMotion = useReducedMotion();
  const isConference = section.kind === "conference";
  const conferenceHref =
    isConference && section.conferenceId !== undefined
      ? `/conference/${section.conferenceId}`
      : undefined;

  const glyph = (() => {
    switch (section.kind) {
      case "following":
        return <Star aria-hidden="true" className="h-4 w-4 shrink-0 fill-current text-text-secondary" />;
      case "top25":
        return <Trophy aria-hidden="true" className="h-4 w-4 shrink-0 text-text-secondary" />;
      case "day":
        return <Calendar aria-hidden="true" className="h-4 w-4 shrink-0 text-text-secondary" />;
      case "conference":
        return <ConferenceLogo src={section.logoUrl} name={section.title} />;
    }
  })();

  const identity = (
    <span className="flex min-w-0 items-center gap-2">
      {glyph}
      <span className="type-section-header truncate text-text-primary">
        {section.title}
      </span>
    </span>
  );

  const countAndChevron = (
    <>
      <span className="type-meta text-text-secondary">
        {section.games.length}
      </span>
      <ChevronDown
        aria-hidden="true"
        className={cn(
          "h-4 w-4 text-text-secondary transition-transform",
          isExpanded && "rotate-180"
        )}
      />
    </>
  );

  const toggleLabel = `${section.title}, ${section.games.length} ${
    section.games.length === 1 ? "game" : "games"
  }`;

  // A conference header splits into two surfaces (iOS 2026-08-25): the mark
  // + name link to the conference page; the count + chevron (a generous
  // target) toggles. Non-conference headers toggle whole-width.
  const headerRow = conferenceHref ? (
    <div className="flex w-full items-stretch bg-bg-header">
      <Link
        href={conferenceHref}
        aria-label={`${section.title} standings`}
        className="flex min-w-0 items-center py-2.5 pl-4 transition-colors hover:bg-bg-elevated/60"
      >
        {identity}
      </Link>
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={isExpanded}
        aria-label={toggleLabel}
        className="flex flex-1 items-center justify-end gap-2 py-2.5 pl-2 pr-4 transition-colors hover:bg-bg-elevated/60"
      >
        {countAndChevron}
      </button>
    </div>
  ) : (
    <button
      type="button"
      onClick={onToggle}
      aria-expanded={isExpanded}
      aria-label={toggleLabel}
      className="flex w-full items-center gap-2 bg-bg-header px-4 py-2.5 text-left transition-colors hover:bg-bg-elevated/60"
    >
      {identity}
      <span className="ml-auto flex items-center gap-2">{countAndChevron}</span>
    </button>
  );

  const rows = (
    <div>
      {section.games.map((game, index) => (
        <div key={game.id}>
          {index > 0 && <div className="ml-4 border-t border-divider" />}
          <GameRow game={game} timeOnly={section.kind === "day"} />
        </div>
      ))}
    </div>
  );

  const collapse = (
    <AnimatePresence initial={false}>
      {isExpanded && (
        <motion.div
          initial={{ height: 0 }}
          animate={{ height: "auto" }}
          exit={{ height: 0 }}
          transition={
            reducedMotion
              ? { duration: 0 }
              : { duration: 0.25, ease: [0.4, 0, 0.2, 1] }
          }
          // Collapsing rows stay inside the card instead of painting over
          // the next section's header (iOS 2026-08-29 `.clipped()`).
          className="overflow-clip"
        >
          {pinsHeader ? (
            <div className="rounded-b-[10px] bg-bg-card shadow-card">{rows}</div>
          ) : (
            rows
          )}
        </motion.div>
      )}
    </AnimatePresence>
  );

  if (pinsHeader) {
    // The header pins while its games scroll but still reads as the card's
    // own top edge: top radii on the header, bottom radii on the rows, zero
    // gap between them.
    return (
      <section>
        <div
          className={cn(
            "sticky top-[104px] z-10 overflow-clip rounded-t-[10px] shadow-card sm:top-[112px]",
            !isExpanded && "rounded-b-[10px]"
          )}
        >
          {headerRow}
        </div>
        {collapse}
      </section>
    );
  }

  return (
    <section className="card-surface">
      {headerRow}
      {collapse}
    </section>
  );
}
