"use client";

// The News tab — iOS `NewsScreen` (Features/News/, E26): For you, your
// followed teams' own stories merged newest first, then one page per league,
// FotMob's News top row adapted. It reverses the brief's N1 ("no News
// tab") on Andy's call; the rest of docs/news.md still holds — text rows,
// the in-app reader, no photos.
//
// Each page is fetched the first time it's shown and kept while the tab is
// open. For you costs a request per followed team (capped), through the
// team page's own news route.

import { useState } from "react";
import Link from "next/link";
import { PageHeader } from "@/components/page-header";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import { StoryListCard, StoryListCardSkeleton } from "@/components/story-list-card";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { useOnDemand } from "@/lib/hooks/use-on-demand";
import { getFollowedNews, getLeagueNews } from "@/lib/api";
import { LEAGUES, isLeague, shortName, type League } from "@/lib/leagues";

const TABS: HeroTab[] = [
  { id: "for-you", label: "For you" },
  ...LEAGUES.map((league) => ({ id: league, label: shortName(league) })),
];

export function NewsView() {
  const [tab, setTab] = useState("for-you");
  const { favorites, isLoaded } = useFavoritesContext();
  const league: League | undefined = isLeague(tab) ? tab : undefined;
  const keys = [...favorites].sort();

  // Keyed by page, and For you by the follows too: a follow added or
  // dropped rebuilds it. Undefined until the stored follows have loaded, so
  // For you never answers "no teams" to someone who has some.
  const key = league
    ? `league:${league}`
    : isLoaded
      ? `for-you:${keys.join(",")}`
      : undefined;
  const feed = useOnDemand(key, () =>
    league ? getLeagueNews(league) : getFollowedNews(keys)
  );

  return (
    <div className="flex flex-col gap-2">
      <PageHeader title="News" />
      <HeroTabBar tabs={TABS} selected={tab} onSelect={setTab} />
      <div role="tabpanel" id={`panel-${tab}`} aria-labelledby={`tab-${tab}`}>
        {feed.state.status === "failed" ? (
          <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
            <p className="type-team-name text-text-secondary">Couldn&apos;t load the news.</p>
            <button
              type="button"
              onClick={feed.reload}
              className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
            >
              Retry
            </button>
          </section>
        ) : feed.state.status === "loading" ? (
          <StoryListCardSkeleton />
        ) : feed.state.value.length > 0 ? (
          <StoryListCard stories={feed.state.value} />
        ) : !league && keys.length === 0 ? (
          // For you with nobody followed is a way to follow someone.
          <section className="card-surface flex flex-col items-center gap-1 px-6 py-8 text-center">
            <p className="type-team-name-em text-text-primary">No teams yet</p>
            <p className="type-meta text-text-secondary">
              Follow teams and their stories collect here.
            </p>
            <Link
              href="/teams"
              className="mt-2 rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
            >
              Add teams
            </Link>
          </section>
        ) : (
          <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
            {league
              ? `No ${shortName(league)} stories right now.`
              : "No stories about your teams right now."}
          </section>
        )}
      </div>
    </div>
  );
}
