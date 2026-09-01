"use client";

import { useState, useMemo } from "react";
import { ChevronUp } from "lucide-react";
import { SearchInput } from "@/components/search-input";
import { motion, AnimatePresence } from "framer-motion";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { ConferenceRow } from "@/components/conference-card";
import { FBS_CONFERENCES, FCS_CONFERENCES } from "@/config/conferences";
import type { Conference } from "@/lib/types";

function matchesQuery(conf: Conference, q: string): boolean {
  const lower = q.toLowerCase();
  return (
    conf.shortName.toLowerCase().includes(lower) ||
    conf.name.toLowerCase().includes(lower)
  );
}

function ConferenceGroupCard({
  title,
  conferences,
  defaultOpen = false,
  showFollowButton = false,
}: {
  title: string;
  conferences: Conference[];
  defaultOpen?: boolean;
  showFollowButton?: boolean;
}) {
  const [isOpen, setIsOpen] = useState(defaultOpen);

  if (conferences.length === 0) return null;

  return (
    <div className="overflow-hidden rounded-xl border bg-card shadow-card">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex w-full items-center gap-3 px-4 py-3 text-left bg-muted/50 transition-colors hover:bg-accent/30"
      >
        <span className="text-sm font-semibold text-foreground">{title}</span>
        <motion.span
          animate={{ rotate: isOpen ? 0 : 180 }}
          transition={{ duration: 0.2 }}
          className="ml-auto"
        >
          <ChevronUp className="h-4 w-4 text-muted-foreground" />
        </motion.span>
      </button>

      <AnimatePresence initial={false}>
        {isOpen && (
          <motion.div
            initial={{ height: 0 }}
            animate={{ height: "auto" }}
            exit={{ height: 0 }}
            transition={{ duration: 0.2, ease: "easeInOut" }}
            className="overflow-hidden"
          >
            <div className="border-t">
              {conferences.map((conf, i) => (
                <div key={conf.id}>
                  {i > 0 && <div className="mx-4 border-t" />}
                  <ConferenceRow
                    id={conf.id}
                    name={conf.name}
                    shortName={conf.shortName}
                    showFollowButton={showFollowButton}
                  />
                </div>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

/** Flat list of search results (no accordion grouping). */
function SearchResults({
  conferences,
  showFollowButton,
  onFollow,
}: {
  conferences: Conference[];
  showFollowButton?: boolean;
  onFollow?: () => void;
}) {
  if (conferences.length === 0) {
    return (
      <p className="py-8 text-center text-sm text-muted-foreground">
        No conferences found
      </p>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border bg-card shadow-card">
      {conferences.map((conf, i) => (
        <div key={conf.id}>
          {i > 0 && <div className="mx-4 border-t" />}
          <ConferenceRow
            id={conf.id}
            name={conf.name}
            shortName={conf.shortName}
            showFollowButton={showFollowButton}
            onFollow={onFollow}
          />
        </div>
      ))}
    </div>
  );
}

export function ConferencesList() {
  const { favoriteConferences, isLoaded } = useFavoritesContext();
  const [query, setQuery] = useState("");

  const allConferences = useMemo(
    () => [...FBS_CONFERENCES, ...FCS_CONFERENCES],
    []
  );

  const followedConferences = allConferences.filter((c) =>
    favoriteConferences.includes(c.id)
  );
  const unfollowedFbs = FBS_CONFERENCES.filter(
    (c) => !favoriteConferences.includes(c.id)
  );
  const unfollowedFcs = FCS_CONFERENCES.filter(
    (c) => !favoriteConferences.includes(c.id)
  );

  const isSearching = query.trim().length > 0;

  const searchResults = useMemo(() => {
    if (!isSearching) return [];
    return allConferences.filter((c) => matchesQuery(c, query.trim()));
  }, [allConferences, query, isSearching]);

  return (
    <div className="space-y-4">
      {/* Search */}
      <SearchInput
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onClear={() => setQuery("")}
        placeholder="Search conferences…"
      />

      {isSearching ? (
        /* Search results — flat list */
        <SearchResults
          conferences={searchResults}
          showFollowButton
          onFollow={() => setQuery("")}
        />
      ) : (
        /* Default view */
        <>
          {/* Following */}
          {isLoaded && followedConferences.length > 0 && (
            <ConferenceGroupCard
              title="Following"
              conferences={followedConferences}
              defaultOpen
              showFollowButton
            />
          )}

          {/* All conferences */}
          <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
            All conferences
          </p>

          {/* FBS */}
          <ConferenceGroupCard
            title="FBS"
            conferences={unfollowedFbs}
            defaultOpen={followedConferences.length === 0}
            showFollowButton
          />

          {/* FCS */}
          <ConferenceGroupCard
            title="FCS"
            conferences={unfollowedFcs}
            showFollowButton
          />
        </>
      )}
    </div>
  );
}
