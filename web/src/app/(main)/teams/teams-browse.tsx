"use client";

// Browse and search the FBS, grouped by conference — the web twin of the
// iOS `TeamsScreen`. Sections collapse per header (state persisted under
// its own localStorage key, default open); the conference name links to
// the conference page while the rest of the header toggles.

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { ChevronDown, Star } from "lucide-react";
import { SearchField } from "@/components/search-field";
import { TeamBrowseRow } from "@/components/team-browse-row";
import { ConferenceLogo } from "@/components/theme/conference-logo";
import { Skeleton } from "@/components/ui/skeleton";
import { useTeamDirectory } from "@/lib/hooks/use-team-directory";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { searchTeams } from "@/lib/search-ranking";
import { conferenceLogoUrl, orderedIds } from "@/lib/conferences";
import { cn } from "@/lib/utils";
import type { ConferenceTeams, Team } from "@/lib/types";

const COLLAPSE_KEY = "statside.teamsBrowse.v1";
const FOLLOWING_SECTION = "following";

/** Collapsed-section ids, persisted like the iOS accordion state. */
function useCollapsedSections() {
  const [collapsed, setCollapsed] = useState<ReadonlySet<string>>(new Set());

  useEffect(() => {
    // Read post-hydration so server markup (everything open) matches.
    try {
      const raw = localStorage.getItem(COLLAPSE_KEY);
      const parsed: unknown = raw ? JSON.parse(raw) : [];
      if (Array.isArray(parsed)) {
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setCollapsed(
          new Set(parsed.filter((id): id is string => typeof id === "string"))
        );
      }
    } catch {
      // Ignore localStorage errors — everything stays open.
    }
  }, []);

  const toggle = useCallback((id: string) => {
    setCollapsed((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      try {
        localStorage.setItem(COLLAPSE_KEY, JSON.stringify([...next]));
      } catch {
        // Ignore localStorage errors
      }
      return next;
    });
  }, []);

  return { collapsed, toggle };
}

export function TeamsBrowse() {
  const { conferences, isLoading, error, retry } = useTeamDirectory();
  const { favorites } = useFavoritesContext();
  const { collapsed, toggle } = useCollapsedSections();
  const [query, setQuery] = useState("");

  // Registry browsing order (P4 → G5 → Independents); a group the registry
  // doesn't know sorts last, alphabetically.
  const ordered = useMemo(() => {
    const rank = (group: ConferenceTeams) => {
      const index = orderedIds.indexOf(Number(group.id));
      return index === -1 ? orderedIds.length : index;
    };
    return [...conferences].sort((lhs, rhs) => {
      const lr = rank(lhs);
      const rr = rank(rhs);
      if (lr !== rr) return lr - rr;
      return lhs.name.localeCompare(rhs.name, "en", { sensitivity: "base" });
    });
  }, [conferences]);

  const followedTeams = useMemo(() => {
    const followedIds = new Set(favorites);
    return conferences
      .flatMap((conference) => conference.teams)
      .filter((team) => followedIds.has(team.id))
      .sort((lhs, rhs) =>
        lhs.school.localeCompare(rhs.school, "en", { sensitivity: "base" })
      );
  }, [conferences, favorites]);

  // No follow boost here: the browse filter's rows carry follow toggles,
  // and a followed-first sort would reorder the list under the pointer.
  const results = useMemo(
    () => searchTeams(query, conferences),
    [query, conferences]
  );

  const trimmed = query.trim();

  return (
    <div>
      <h1 className="sr-only">Teams</h1>
      <div className="sticky top-14 z-40 -mx-4 bg-bg-recessed px-4 pb-2 pt-1 sm:top-16">
        <SearchField value={query} onChange={setQuery} placeholder="Find a team" />
      </div>

      {conferences.length === 0 ? (
        isLoading ? (
          <DirectorySkeleton />
        ) : (
          <div className="flex flex-col items-center gap-3 py-20">
            <p className="type-team-name text-text-secondary">
              {error ?? "No teams"}
            </p>
            <button
              type="button"
              onClick={retry}
              className="type-team-name-em text-text-primary"
            >
              Retry
            </button>
          </div>
        )
      ) : trimmed.length === 0 ? (
        <div className="space-y-2">
          {followedTeams.length > 0 && (
            <FollowingSection
              teams={followedTeams}
              expanded={!collapsed.has(FOLLOWING_SECTION)}
              onToggle={() => toggle(FOLLOWING_SECTION)}
            />
          )}
          <h2 className="px-3 pt-2 type-team-name-em text-text-primary">
            All conferences
          </h2>
          {ordered.map((conference) => (
            <ConferenceSection
              key={conference.id ?? conference.name}
              conference={conference}
              expanded={!collapsed.has(sectionId(conference))}
              onToggle={() => toggle(sectionId(conference))}
            />
          ))}
        </div>
      ) : results.length > 0 ? (
        <div className="card-surface py-1">
          {results.map((team) => (
            <TeamBrowseRow key={team.id} team={team} />
          ))}
        </div>
      ) : (
        <p className="py-16 text-center type-team-name text-text-secondary">
          No teams match &ldquo;{trimmed}&rdquo;
        </p>
      )}
    </div>
  );
}

function sectionId(conference: ConferenceTeams): string {
  return `conf.${conference.id ?? "other"}`;
}

function SectionChevron({ expanded }: { expanded: boolean }) {
  return (
    <ChevronDown
      aria-hidden="true"
      className={cn(
        "h-3.5 w-3.5 text-text-secondary transition-transform",
        expanded && "rotate-180"
      )}
    />
  );
}

function teamCountLabel(count: number): string {
  return `${count} ${count === 1 ? "team" : "teams"}`;
}

/** Followed teams, alphabetical — the whole header is the toggle. */
function FollowingSection({
  teams,
  expanded,
  onToggle,
}: {
  teams: Team[];
  expanded: boolean;
  onToggle: () => void;
}) {
  return (
    <section className="card-surface">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={expanded}
        aria-label={`Following, ${teamCountLabel(teams.length)}`}
        className="flex w-full items-center gap-2 bg-bg-header px-4 py-2.5 text-left transition-colors hover:bg-bg-elevated"
      >
        <Star
          aria-hidden="true"
          className="h-[18px] w-[18px] fill-current text-text-primary"
        />
        <span className="type-section-header text-text-primary">Following</span>
        <span className="type-meta text-text-secondary">{teams.length}</span>
        <span className="ml-auto">
          <SectionChevron expanded={expanded} />
        </span>
      </button>
      {expanded && (
        <div className="py-1">
          {teams.map((team) => (
            <TeamBrowseRow key={team.id} team={team} />
          ))}
        </div>
      )}
    </section>
  );
}

/**
 * One conference accordion. The header splits into two surfaces (the iOS
 * 2026-08-25 call): mark + name push the conference page, the rest of the
 * row toggles. A group without a registry id keeps the whole row as toggle.
 */
function ConferenceSection({
  conference,
  expanded,
  onToggle,
}: {
  conference: ConferenceTeams;
  expanded: boolean;
  onToggle: () => void;
}) {
  const numericId = conference.id !== undefined ? Number(conference.id) : NaN;
  const identity = (
    <>
      <ConferenceLogo
        src={Number.isFinite(numericId) ? conferenceLogoUrl(numericId) : null}
        name=""
      />
      <span className="type-section-header text-text-primary">
        {conference.name}
      </span>
    </>
  );
  const countAndChevron = (
    <>
      <span className="type-meta text-text-secondary">
        {conference.teams.length}
      </span>
      <span className="ml-auto">
        <SectionChevron expanded={expanded} />
      </span>
    </>
  );

  return (
    <section className="card-surface">
      <div className="flex items-stretch bg-bg-header">
        {conference.id !== undefined ? (
          <>
            <Link
              href={`/conference/${conference.id}`}
              aria-label={`${conference.name} standings`}
              className="flex items-center gap-2 py-2.5 pl-4 transition-colors hover:bg-bg-elevated"
            >
              {identity}
            </Link>
            <button
              type="button"
              onClick={onToggle}
              aria-expanded={expanded}
              aria-label={`${conference.name}, ${teamCountLabel(conference.teams.length)}`}
              className="flex flex-1 items-center gap-2 py-2.5 pl-2 pr-4 text-left transition-colors hover:bg-bg-elevated"
            >
              {countAndChevron}
            </button>
          </>
        ) : (
          <button
            type="button"
            onClick={onToggle}
            aria-expanded={expanded}
            aria-label={`${conference.name}, ${teamCountLabel(conference.teams.length)}`}
            className="flex flex-1 items-center gap-2 px-4 py-2.5 text-left transition-colors hover:bg-bg-elevated"
          >
            {identity}
            {countAndChevron}
          </button>
        )}
      </div>
      {expanded && (
        <div className="py-1">
          {conference.teams.map((team) => (
            <TeamBrowseRow key={team.id} team={team} />
          ))}
        </div>
      )}
    </section>
  );
}

function DirectorySkeleton() {
  return (
    <div className="space-y-2" aria-hidden="true">
      {Array.from({ length: 4 }).map((_, i) => (
        <div key={i} className="card-surface">
          <div className="bg-bg-header px-4 py-2.5">
            <Skeleton className="h-4 w-28" />
          </div>
          <div className="space-y-2 px-4 py-3">
            <Skeleton className="h-5 w-3/4" />
            <Skeleton className="h-5 w-2/3" />
            <Skeleton className="h-5 w-3/5" />
          </div>
        </div>
      ))}
    </div>
  );
}
