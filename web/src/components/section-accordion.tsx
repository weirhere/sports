"use client";

// One collapsible section of the scores list — the iOS `SectionAccordion`
// (sports/Features/Scores/SectionAccordion.swift): bg-header header row,
// hairline-divided game rows when expanded. Replaces the old day-group /
// conference-group / my-teams-section trio with one component fed by the
// game-sections engine.

import Link from "next/link";
import { ChevronDown, Star } from "lucide-react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { isLiveStatus, type GameSection } from "@/lib/game-sections";
import { displayName, shortName } from "@/lib/leagues";
import { GameRow } from "./game-row";
import { ConferenceLogo } from "./theme/conference-logo";
import { cn } from "@/lib/utils";
import { conferencePath } from "@/lib/routes";
import { ACCORDION_TRANSITION, INSTANT_TRANSITION } from "@/lib/motion";

interface SectionAccordionProps {
  section: GameSection;
  isExpanded: boolean;
  onToggle: () => void;
}

export function SectionAccordion({
  section,
  isExpanded,
  onToggle,
}: SectionAccordionProps) {
  const reducedMotion = useReducedMotion();
  // A header that names a real table splits into two surfaces (iOS
  // 2026-08-25, restored 2026-09-06 once a header had somewhere to go): the
  // mark + name push that table's page, the rest toggles. The poll is a
  // table too — its name opens the Top 25 page, the same page the Leagues
  // hub's row does. Following and "Other" keep the whole row: there is
  // nowhere for their name to go.
  const nameHref =
    section.conference !== undefined
      ? conferencePath(section.conference)
      : section.table?.kind === "poll"
        ? "/rankings/poll"
        : undefined;
  // Named for what the tap does, not what it says.
  const nameAction = section.table?.kind === "poll" ? "rankings" : "standings";

  const glyph =
    section.kind === "following" ? (
      <Star
        aria-hidden="true"
        className="h-4 w-4 shrink-0 fill-current text-text-secondary"
      />
    ) : (
      <ConferenceLogo src={section.logoUrl} name={section.title} />
    );

  /**
   * The league tag (iOS, 2026-09-07). Breaking college football back into
   * conferences left every header on the page naming a conference and none
   * of them naming a sport — "ACC" is only obviously college football to
   * someone who already knows. Joined onto the title as "SEC - NCAAF" since
   * 2026-09-25, rather than riding it as a smaller caption.
   *
   * Only where the section has a league and doesn't already say it: the
   * NFL's own section is titled "NFL", and Following spans leagues.
   */
  const leagueTag =
    section.league !== undefined &&
    section.title !== displayName(section.league)
      ? shortName(section.league)
      : undefined;

  // VoiceOver hears the long form — "ACC, college football, 8 games" —
  // where the chip shows the short one.
  const spokenLeague = leagueTag
    ? `, ${displayName(section.league!)}`
    : "";

  const identity = (
    <span className="flex min-w-0 items-baseline gap-2">
      <span className="flex shrink-0 items-center self-center">{glyph}</span>
      <span className="type-section-header truncate text-text-primary">
        {leagueTag ? `${section.title} - ${leagueTag}` : section.title}
      </span>
    </span>
  );

  // The count is a badge beside the chevron (iOS, 2026-09-25): a tally of
  // the section, not part of its name. Only while collapsed — open, the rows
  // are the count — and live ("2/3", in the Live chip's green) while any of
  // the section's games is being played.
  const liveCount = section.games.filter((g) => isLiveStatus(g.status)).length;
  const countAndChevron = (
    <>
      {!isExpanded && (
        <span
          aria-hidden="true"
          className={cn(
            "type-meta inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-full px-1.5 font-semibold tabular-nums",
            liveCount > 0
              ? "border border-live-edge bg-live-tint text-live"
              : "bg-divider text-text-secondary"
          )}
        >
          {liveCount > 0
            ? `${liveCount}/${section.games.length}`
            : section.games.length}
        </span>
      )}
      <ChevronDown
        aria-hidden="true"
        className={cn(
          "h-4 w-4 text-text-secondary transition-transform duration-[180ms] ease-out motion-reduce:transition-none",
          isExpanded && "rotate-180"
        )}
      />
    </>
  );

  const toggleLabel = `${section.title}${spokenLeague}, ${section.games.length} ${
    section.games.length === 1 ? "game" : "games"
  }${liveCount > 0 ? `, ${liveCount} live` : ""}`;

  // The mark + name push the table's page; the count + chevron (a generous
  // target) toggles. Every other header toggles whole-width.
  const headerRow = nameHref ? (
    <div className="flex w-full items-stretch bg-bg-header">
      <Link
        href={nameHref}
        aria-label={`${section.title}${spokenLeague} ${nameAction}`}
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
        <div key={`${game.league}-${game.id}`}>
          {index > 0 && <div className="ml-4 border-t border-divider" />}
          <GameRow game={game} />
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
          // 0.18s ease-out, not the 0.25s material curve this had (iOS,
          // 2026-09-24) — shared with Hide all/Show all.
          transition={
            reducedMotion ? INSTANT_TRANSITION : ACCORDION_TRANSITION
          }
          // Collapsing rows stay inside the card instead of painting over
          // the next section's header (iOS 2026-08-29 `.clipped()`).
          className="overflow-clip"
        >
          {rows}
        </motion.div>
      )}
    </AnimatePresence>
  );

  return (
    <section className="card-surface">
      {headerRow}
      {collapse}
    </section>
  );
}
