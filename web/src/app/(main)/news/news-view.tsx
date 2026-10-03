"use client";

// The News tab — iOS `NewsScreen` (Features/News/, E26): For you, then one
// page per league, FotMob's News top row adapted. It reverses the brief's N1
// ("no News tab") on Andy's call, and its photos supersede N8 (the color
// budget's sixth exception, 2026-09-27); the in-app reader still holds.
//
// For you is FotMob's sectioned feed (Mobbin `bfd98a17`): Trending, one
// section per followed team with "See more" to that team's News tab, then
// Latest. A league page is one section whose "See more" opens the league's
// own News tab.
//
// Each page is fetched the first time it's shown and kept while the tab is
// open.

import { useMemo, useState } from "react";
import Link from "next/link";
import { PageHeader } from "@/components/page-header";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import { StorySection, StorySectionSkeleton } from "@/components/story-section";
import { FeaturedStory } from "@/components/featured-story";
import { TeamLogo } from "@/components/team-logo";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { useOnDemand } from "@/lib/hooks/use-on-demand";
import { useTeamDirectory } from "@/lib/hooks/use-team-directory";
import { getForYouPage, getLeagueNews, type ForYouPage } from "@/lib/api";
import { LEAGUES, isLeague, shortName, type League } from "@/lib/leagues";
import { leagueWideId } from "@/lib/conferences";
import { followKey, followedLeagues, parseFollowKey } from "@/lib/refs";
import { conferencePath, pollPath, teamPath } from "@/lib/routes";
import { teamFullName } from "@/lib/team-name";
import type { NewsStory } from "@/lib/news";
import type { Team } from "@/lib/types";

const TABS: HeroTab[] = [
  { id: "for-you", label: "For you" },
  ...LEAGUES.map((league) => ({ id: league, label: shortName(league) })),
];

type Loaded = { kind: "league"; stories: NewsStory[] } | { kind: "for-you"; page: ForYouPage };

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
  const feed = useOnDemand<Loaded>(key, async () =>
    league
      ? { kind: "league", stories: await getLeagueNews(league) }
      : { kind: "for-you", page: await getForYouPage(keys) }
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
          <StorySectionSkeleton />
        ) : feed.state.value.kind === "league" && league ? (
          <LeaguePage league={league} stories={feed.state.value.stories} />
        ) : feed.state.value.kind === "for-you" ? (
          <ForYou page={feed.state.value.page} keys={keys} />
        ) : null}
      </div>
    </div>
  );
}

/** One section, and "See more" to the league's own News tab: the Top 25 for
 *  college football, the league-wide conference page for the rest. */
function LeaguePage({ league, stories }: { league: League; stories: NewsStory[] }) {
  if (stories.length === 0) {
    return (
      <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
        No {shortName(league)} stories right now.
      </section>
    );
  }
  const wideId = leagueWideId(league);
  const seeMoreHref =
    league === "cfb"
      ? pollPath({ tab: "news" })
      : wideId !== undefined
        ? conferencePath({ league, id: wideId }, { tab: "news" })
        : undefined;
  return <StorySection stories={stories} seeMoreHref={seeMoreHref} priority />;
}

function Heading({ children }: { children: React.ReactNode }) {
  return (
    <h2 className="flex items-center gap-2 px-1 pt-3 type-team-name-em text-text-primary">
      {children}
    </h2>
  );
}

function ForYou({ page, keys }: { page: ForYouPage; keys: string[] }) {
  // The followed teams with stories, in the Teams tab's order (by school).
  // The directory names them and draws their marks; when it hasn't loaded,
  // a story's own team tag names the team and the league's logo bucket
  // draws it, so a directory miss never drops a section whose stories came.
  const leagues = useMemo(() => followedLeagues(keys), [keys]);
  const directory = useTeamDirectory(leagues);
  const sections = useMemo(() => {
    const byKey = new Map<string, Team>();
    for (const team of directory.conferences.flatMap((conference) => conference.teams)) {
      byKey.set(followKey({ league: team.league, teamId: team.id }), team);
    }
    return Object.entries(page.teams)
      .flatMap(([key, stories]) => {
        const ref = parseFollowKey(key);
        if (!ref) return [];
        const team = byKey.get(key);
        const tag = stories
          .flatMap((story) => story.teams)
          .find((entry) => entry.id === ref.teamId)?.name;
        const name = team ? teamFullName(team) : (tag ?? "");
        const sortKey = team?.school ?? name;
        const logo = team ?? { espnId: Number(ref.teamId), league: ref.league, logoUrl: "" };
        return [{ key, ref, name, sortKey, logo, stories }];
      })
      .sort((a, b) => a.sortKey.localeCompare(b.sortKey));
  }, [directory.conferences, page.teams]);

  return (
    <div className="flex flex-col gap-2">
      {page.trending.length > 0 && (
        <>
          <Heading>Trending</Heading>
          <StorySection stories={page.trending} priority />
        </>
      )}
      {sections.map(({ key, ref, name, logo, stories }) => (
        <div key={key} className="flex flex-col gap-2">
          <Heading>
            <TeamLogo team={logo} teamName="" size="sm" className="h-5 w-5" />
            {name}
          </Heading>
          <StorySection stories={stories} seeMoreHref={teamPath(ref, { tab: "news" })} />
        </div>
      ))}
      {keys.length === 0 && (
        // Nobody followed still has Trending and Latest; this is where the
        // team sections would be.
        <section className="card-surface flex flex-col items-center gap-1 px-6 py-8 text-center">
          <p className="type-team-name-em text-text-primary">No teams yet</p>
          <p className="type-meta text-text-secondary">
            Follow teams and their stories get a section here.
          </p>
          <Link
            href="/teams"
            className="mt-2 rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
          >
            Add teams
          </Link>
        </section>
      )}
      {page.latest.length > 0 && (
        <>
          <Heading>Latest</Heading>
          {/* One story per card, full width: FotMob's Latest. */}
          {page.latest.map((story) => (
            <section key={story.id} className="card-surface">
              <FeaturedStory story={story} />
            </section>
          ))}
        </>
      )}
      {page.trending.length === 0 && page.latest.length === 0 && sections.length === 0 &&
        keys.length > 0 && (
          <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
            No stories right now.
          </section>
        )}
    </div>
  );
}
