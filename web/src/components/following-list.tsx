"use client";

import { useState, useMemo, useRef, useEffect } from "react";
import Link from "next/link";
import { Heart, GripVertical, Plus, X } from "lucide-react";
import { SearchInput } from "@/components/search-input";
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  arrayMove,
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { MOCK_TEAMS } from "@/lib/mock/teams";
import { ALL_CONFERENCES } from "@/config/conferences";
import { TeamLogo } from "@/components/team-logo";
import { FavoriteButton } from "@/components/favorite-button";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";
import { useSwipe } from "@/lib/hooks/use-swipe";
import type { Team } from "@/lib/types";
import type { Conference } from "@/lib/types";

/* ------------------------------------------------------------------ */
/*  Sortable team row                                                  */
/* ------------------------------------------------------------------ */
function SortableTeamRow({ team }: { team: Team }) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: team.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={cn(
        "flex items-center gap-1 bg-card",
        isDragging && "relative z-50 shadow-lg rounded-lg"
      )}
    >
      <button
        type="button"
        className="flex shrink-0 touch-none items-center justify-center px-2 py-3 text-muted-foreground/40 hover:text-muted-foreground"
        aria-label="Drag to reorder"
        {...attributes}
        {...listeners}
      >
        <GripVertical className="h-4 w-4" />
      </button>
      <Link
        href={`/team/${team.id}`}
        className="flex min-w-0 flex-1 items-center gap-3 py-3 pr-4 transition-colors hover:bg-accent/30"
      >
        <TeamLogo
          espnId={team.espnId}
          teamName={team.school}
          size="sm"
        />
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold">{team.school}</p>
          <p className="text-xs text-muted-foreground">
            {team.conferenceName}
          </p>
        </div>
        <FavoriteButton teamId={team.id} size="sm" />
      </Link>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  Sortable conference row                                            */
/* ------------------------------------------------------------------ */
function SortableConferenceRow({ conf }: { conf: Conference }) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: conf.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={cn(
        "flex items-center gap-1 bg-card",
        isDragging && "relative z-50 shadow-lg rounded-lg"
      )}
    >
      <button
        type="button"
        className="flex shrink-0 touch-none items-center justify-center px-2 py-3 text-muted-foreground/40 hover:text-muted-foreground"
        aria-label="Drag to reorder"
        {...attributes}
        {...listeners}
      >
        <GripVertical className="h-4 w-4" />
      </button>
      <Link
        href={`/conferences/${conf.id}`}
        className="flex min-w-0 flex-1 items-center gap-3 py-3 pr-4 transition-colors hover:bg-accent/30"
      >
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold">{conf.shortName}</p>
          <p className="text-xs text-muted-foreground">
            {conf.name}
          </p>
        </div>
        <FavoriteButton
          teamId={conf.id}
          type="conference"
          size="sm"
        />
      </Link>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  Add search panel                                                   */
/* ------------------------------------------------------------------ */
function AddTeamSearch({ onClose }: { onClose: () => void }) {
  const [query, setQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const { isFavorite, toggleFavorite } = useFavoritesContext();

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const results = useMemo(() => {
    if (!query.trim()) return MOCK_TEAMS.filter((t) => !isFavorite(t.id)).slice(0, 10);
    const q = query.toLowerCase();
    return MOCK_TEAMS.filter(
      (t) =>
        (t.school.toLowerCase().includes(q) ||
          t.name.toLowerCase().includes(q) ||
          t.abbreviation.toLowerCase().includes(q) ||
          t.conferenceName.toLowerCase().includes(q)) &&
        !isFavorite(t.id)
    );
  }, [query, isFavorite]);

  return (
    <div className="space-y-3">
      {/* Search input */}
      <SearchInput
        ref={inputRef}
        placeholder="Search teams..."
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onClear={onClose}
      />

      {/* Results */}
      {results.length > 0 ? (
        <div className="overflow-hidden rounded-xl border bg-card shadow-card">
          {results.map((team, i) => (
            <div key={team.id}>
              {i > 0 && <div className="mx-4 border-t" />}
              <div className="flex items-center gap-3 px-4 py-3">
                <TeamLogo espnId={team.espnId} teamName={team.school} size="sm" />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold">{team.school}</p>
                  <p className="text-xs text-muted-foreground">{team.conferenceName}</p>
                </div>
                <button
                  type="button"
                  onClick={() => toggleFavorite(team.id)}
                  className="shrink-0 rounded-full border border-border bg-transparent px-3 py-1 text-xs font-medium text-muted-foreground transition-colors hover:border-foreground/30 hover:text-foreground"
                >
                  Follow
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <p className="py-6 text-center text-sm text-muted-foreground">
          {query.trim() ? "No teams found" : "All teams are already followed"}
        </p>
      )}
    </div>
  );
}

function AddConferenceSearch({ onClose }: { onClose: () => void }) {
  const [query, setQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const { isFavoriteConference, toggleFavoriteConference } = useFavoritesContext();

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const results = useMemo(() => {
    if (!query.trim()) return ALL_CONFERENCES.filter((c) => !isFavoriteConference(c.id));
    const q = query.toLowerCase();
    return ALL_CONFERENCES.filter(
      (c) =>
        (c.name.toLowerCase().includes(q) ||
          c.shortName.toLowerCase().includes(q)) &&
        !isFavoriteConference(c.id)
    );
  }, [query, isFavoriteConference]);

  return (
    <div className="space-y-3">
      {/* Search input */}
      <SearchInput
        ref={inputRef}
        placeholder="Search conferences..."
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onClear={onClose}
      />

      {/* Results */}
      {results.length > 0 ? (
        <div className="overflow-hidden rounded-xl border bg-card shadow-card">
          {results.map((conf, i) => (
            <div key={conf.id}>
              {i > 0 && <div className="mx-4 border-t" />}
              <div className="flex items-center gap-3 px-4 py-3">
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold">{conf.shortName}</p>
                  <p className="text-xs text-muted-foreground">{conf.name}</p>
                </div>
                <button
                  type="button"
                  onClick={() => toggleFavoriteConference(conf.id)}
                  className="shrink-0 rounded-full border border-border bg-transparent px-3 py-1 text-xs font-medium text-muted-foreground transition-colors hover:border-foreground/30 hover:text-foreground"
                >
                  Follow
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <p className="py-6 text-center text-sm text-muted-foreground">
          {query.trim() ? "No conferences found" : "All conferences are already followed"}
        </p>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/*  Main component                                                     */
/* ------------------------------------------------------------------ */
export function FollowingList() {
  const {
    favorites,
    favoriteConferences,
    reorderFavorites,
    reorderFavoriteConferences,
    isLoaded,
  } = useFavoritesContext();
  const [tab, setTab] = useState("teams");
  const [isAdding, setIsAdding] = useState(false);

  const TABS_ORDER = ["teams", "conferences"] as const;
  const currentTabIndex = TABS_ORDER.indexOf(tab as (typeof TABS_ORDER)[number]);

  const { ref: swipeRef } = useSwipe({
    onSwipeLeft: () => {
      if (currentTabIndex < TABS_ORDER.length - 1) {
        const next = TABS_ORDER[currentTabIndex + 1];
        setTab(next);
        setIsAdding(false);
      }
    },
    onSwipeRight: () => {
      if (currentTabIndex > 0) {
        const prev = TABS_ORDER[currentTabIndex - 1];
        setTab(prev);
        setIsAdding(false);
      }
    },
  });

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: { distance: 5 },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  /* Build ordered lists based on the favorites array order */
  const teamMap = useMemo(() => {
    const map = new Map<string, Team>();
    for (const t of MOCK_TEAMS) map.set(t.id, t);
    return map;
  }, []);

  const confMap = useMemo(() => {
    const map = new Map<string, Conference>();
    for (const c of ALL_CONFERENCES) map.set(c.id, c);
    return map;
  }, []);

  const followedTeams = useMemo(
    () =>
      favorites
        .map((id) => teamMap.get(id))
        .filter((t): t is Team => !!t),
    [favorites, teamMap]
  );

  const followedConfs = useMemo(
    () =>
      favoriteConferences
        .map((id) => confMap.get(id))
        .filter((c): c is Conference => !!c),
    [favoriteConferences, confMap]
  );

  if (!isLoaded) return null;

  const empty = followedTeams.length === 0 && followedConfs.length === 0;

  if (empty && !isAdding) {
    return (
      <div className="flex flex-col items-center justify-center gap-3 py-20 text-center">
        <Heart className="h-10 w-10 text-muted-foreground/40" />
        <p className="text-sm font-medium text-muted-foreground">
          You&apos;re not following anything yet
        </p>
        <p className="max-w-xs text-xs text-muted-foreground/70">
          Follow teams and conferences to see their games here and on the scores
          page.
        </p>
        <button
          type="button"
          onClick={() => setIsAdding(true)}
          className="mt-2 inline-flex items-center gap-1.5 rounded-full border border-border px-4 py-1.5 text-sm font-medium text-muted-foreground transition-colors hover:border-foreground/30 hover:text-foreground"
        >
          <Plus className="h-3.5 w-3.5" />
          Add teams or conferences
        </button>
      </div>
    );
  }

  function handleTeamDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const oldIndex = favorites.indexOf(active.id as string);
    const newIndex = favorites.indexOf(over.id as string);
    if (oldIndex === -1 || newIndex === -1) return;

    reorderFavorites(arrayMove(favorites, oldIndex, newIndex));
  }

  function handleConfDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const oldIndex = favoriteConferences.indexOf(active.id as string);
    const newIndex = favoriteConferences.indexOf(over.id as string);
    if (oldIndex === -1 || newIndex === -1) return;

    reorderFavoriteConferences(
      arrayMove(favoriteConferences, oldIndex, newIndex)
    );
  }

  return (
    <Tabs
      value={tab}
      onValueChange={(v) => {
        setTab(v);
        setIsAdding(false);
      }}
      className="space-y-4"
    >
      {/* Tab bar with add button */}
      <div className="flex items-center justify-between gap-3">
        <TabsList className="flex-1">
          <TabsTrigger value="teams">Teams</TabsTrigger>
          <TabsTrigger value="conferences">Conferences</TabsTrigger>
        </TabsList>

        <button
          type="button"
          onClick={() => setIsAdding(!isAdding)}
          className={cn(
            "flex h-9 w-9 shrink-0 items-center justify-center rounded-full border transition-colors",
            isAdding
              ? "border-foreground/20 bg-foreground/5 text-foreground"
              : "border-border text-muted-foreground hover:border-foreground/30 hover:text-foreground"
          )}
          aria-label={isAdding ? "Close" : `Add ${tab === "teams" ? "team" : "conference"}`}
        >
          {isAdding ? <X className="h-3.5 w-3.5" /> : <Plus className="h-3.5 w-3.5" />}
        </button>
      </div>

      {/* Add search panel */}
      {isAdding && (
        tab === "teams" ? (
          <AddTeamSearch onClose={() => setIsAdding(false)} />
        ) : (
          <AddConferenceSearch onClose={() => setIsAdding(false)} />
        )
      )}

      <div ref={swipeRef}>
        {/* Teams list */}
        <TabsContent value="teams">
          {!isAdding && (
            followedTeams.length > 0 ? (
              <DndContext
                sensors={sensors}
                collisionDetection={closestCenter}
                onDragEnd={handleTeamDragEnd}
              >
                <SortableContext
                  items={followedTeams.map((t) => t.id)}
                  strategy={verticalListSortingStrategy}
                >
                  <div className="overflow-hidden rounded-xl border bg-card shadow-card">
                    {followedTeams.map((team, i) => (
                      <div key={team.id}>
                        {i > 0 && <div className="mx-4 border-t" />}
                        <SortableTeamRow team={team} />
                      </div>
                    ))}
                  </div>
                </SortableContext>
              </DndContext>
            ) : (
              <p className="py-8 text-center text-sm text-muted-foreground">
                No teams followed yet
              </p>
            )
          )}
        </TabsContent>

        {/* Conferences list */}
        <TabsContent value="conferences">
          {!isAdding && (
            followedConfs.length > 0 ? (
              <DndContext
                sensors={sensors}
                collisionDetection={closestCenter}
                onDragEnd={handleConfDragEnd}
              >
                <SortableContext
                  items={followedConfs.map((c) => c.id)}
                  strategy={verticalListSortingStrategy}
                >
                  <div className="overflow-hidden rounded-xl border bg-card shadow-card">
                    {followedConfs.map((conf, i) => (
                      <div key={conf.id}>
                        {i > 0 && <div className="mx-4 border-t" />}
                        <SortableConferenceRow conf={conf} />
                      </div>
                    ))}
                  </div>
                </SortableContext>
              </DndContext>
            ) : (
              <p className="py-8 text-center text-sm text-muted-foreground">
                No conferences followed yet
              </p>
            )
          )}
        </TabsContent>
      </div>
    </Tabs>
  );
}
