"use client";

// The News tab — iOS `NewsScreen` (Features/News/, E26): every league's
// stories in one place, FotMob's News top row adapted. It reverses the
// brief's N1 ("no News tab") on Andy's call, and its photos supersede N8
// (the color budget's sixth exception, 2026-09-27); the in-app reader still
// holds.
//
// Four pages (Andy, 2026-10-19): **For you**, Trending and a section per
// followed team you've kept on it; **Latest**, every league newest first;
// **Transfers**, the roster moves among them; and **Leagues**, each
// league's own stories in the Leagues tab's order. The last three are the
// same four feeds read three ways, fetched once and kept while the tab is
// open.

import { useMemo, useState } from "react";
import Link from "next/link";
import { SlidersHorizontal } from "lucide-react";
import { PageHeader } from "@/components/page-header";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import { StorySection, StorySectionSkeleton } from "@/components/story-section";
import { StoryCardStack } from "@/components/story-card-stack";
import { ForYouTeamsSheet } from "@/components/for-you-teams-sheet";
import { TeamLogo } from "@/components/team-logo";
import { ConferenceLogo } from "@/components/theme/conference-logo";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { useOnDemand } from "@/lib/hooks/use-on-demand";
import { useTeamDirectory } from "@/lib/hooks/use-team-directory";
import { useNewsHiddenTeams } from "@/lib/hooks/use-news-hidden-teams";
import { getForYouTeams, getLeaguePages, type ForYouTeams, type LeaguePages } from "@/lib/api";
import { LEAGUE_DISPLAY_ORDER, leagueLogoUrl, shortName } from "@/lib/leagues";
import { leagueWideId } from "@/lib/conferences";
import { followKey, followedLeagues, parseFollowKey } from "@/lib/refs";
import { conferencePath, pollPath, teamPath } from "@/lib/routes";
import { teamFullName } from "@/lib/team-name";
import { visibleFollowKeys } from "@/lib/news-filter";
import { latestStories, transferStories, trendingStories, type NewsStory } from "@/lib/news";
import type { Team } from "@/lib/types";

const TABS: HeroTab[] = [
  { id: "for-you", label: "For you" },
  { id: "latest", label: "Latest" },
  { id: "transfers", label: "Transfers" },
  { id: "leagues", label: "Leagues" },
];

export function NewsView() {
  const [tab, setTab] = useState("for-you");
  const [isChoosingTeams, setIsChoosingTeams] = useState(false);
  const { favorites, isLoaded } = useFavoritesContext();
  const hidden = useNewsHiddenTeams();
  const keys = useMemo(() => [...favorites].sort(), [favorites]);
  // The follows For you shows: everyone followed, less the sheet's
  // unchecked. What the page is keyed by and fetched for.
  const visibleKeys = useMemo(() => visibleFollowKeys(keys, hidden.hidden), [keys, hidden.hidden]);

  // The four league pages, once for every tab.
  const leagues = useOnDemand<LeaguePages>("leagues", getLeaguePages);
  // For you's team feeds, keyed by the follows it shows: a follow added,
  // dropped or hidden rebuilds them. Undefined until the stored follows and
  // the hidden set have loaded, so For you never answers "no teams" to
  // someone who has some.
  const teamsKey =
    isLoaded && hidden.isLoaded ? `for-you:${visibleKeys.join(",")}` : undefined;
  const teams = useOnDemand<ForYouTeams>(teamsKey, () => getForYouTeams(visibleKeys));

  // The followed teams, in the Teams tab's order, for the sheet and the
  // section headings.
  const followedTeams = useFollowedTeams(keys);

  const reload = () => {
    leagues.reload();
    teams.reload();
  };

  return (
    <div className="flex flex-col gap-2">
      <PageHeader
        title="News"
        trailing={
          tab === "for-you" ? (
            // The door to the For you sheet, in the slot Teams gives its
            // plus: the same round control, so the two read as one class.
            <button
              type="button"
              onClick={() => setIsChoosingTeams(true)}
              aria-label="Choose teams"
              className="flex h-11 w-11 items-center justify-center rounded-full bg-bg-card text-text-primary transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none"
            >
              <SlidersHorizontal aria-hidden="true" className="h-4 w-4" />
            </button>
          ) : undefined
        }
      />
      <HeroTabBar tabs={TABS} selected={tab} onSelect={setTab} />
      <div role="tabpanel" id={`panel-${tab}`} aria-labelledby={`tab-${tab}`}>
        {tab === "for-you" ? (
          <ForYou
            leagues={leagues.state}
            teams={teams.state}
            keys={keys}
            visibleKeys={visibleKeys}
            followedTeams={followedTeams}
            onReload={reload}
          />
        ) : leagues.state.status === "failed" ? (
          <Failed onRetry={leagues.reload} />
        ) : leagues.state.status === "loading" ? (
          <StorySectionSkeleton />
        ) : tab === "latest" ? (
          <Stack stories={latestStories(leagues.state.value.merged)} empty="No stories right now." />
        ) : tab === "transfers" ? (
          <Stack
            stories={transferStories(leagues.state.value.merged)}
            empty="No transfer stories right now."
          />
        ) : (
          <LeaguesPage pages={leagues.state.value.pages} />
        )}
      </div>
      <ForYouTeamsSheet
        open={isChoosingTeams}
        onOpenChange={setIsChoosingTeams}
        teams={followedTeams}
        isShown={hidden.isShown}
        onSetShown={hidden.setShown}
      />
    </div>
  );
}

/** The followed teams the directory knows, A–Z by school (the Teams tab's
 *  order). A team the directory hasn't answered for yet is left out, and
 *  arrives with it. */
function useFollowedTeams(keys: string[]): Team[] {
  const leagues = useMemo(() => followedLeagues(keys), [keys]);
  const directory = useTeamDirectory(leagues);
  return useMemo(() => {
    const wanted = new Set(keys);
    return directory.conferences
      .flatMap((conference) => conference.teams)
      .filter((team) => wanted.has(followKey({ league: team.league, teamId: team.id })))
      .sort((a, b) => a.school.localeCompare(b.school));
  }, [directory.conferences, keys]);
}

function Failed({ onRetry }: { onRetry: () => void }) {
  return (
    <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
      <p className="type-team-name text-text-secondary">Couldn&apos;t load the news.</p>
      <button
        type="button"
        onClick={onRetry}
        className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
      >
        Retry
      </button>
    </section>
  );
}

function Empty({ children }: { children: React.ReactNode }) {
  return (
    <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
      {children}
    </section>
  );
}

/** Latest and Transfers: one story per card, full width. */
function Stack({ stories, empty }: { stories: NewsStory[]; empty: string }) {
  if (stories.length === 0) return <Empty>{empty}</Empty>;
  return (
    <div className="flex flex-col gap-2">
      <StoryCardStack stories={stories} priority />
    </div>
  );
}

/** A News page's section heading: a 20px mark and a name, with room at the
 *  trailing edge for a link (iOS `NewsSectionHeading`). */
function Heading({
  logo,
  children,
  trailing,
}: {
  logo?: React.ReactNode;
  children: React.ReactNode;
  trailing?: React.ReactNode;
}) {
  return (
    <div className="flex items-baseline gap-2 px-1 pt-3">
      {/* 20px (Andy, 2026-10-19), up from the list heading's 15; iOS
          `NewsSectionHeading`. */}
      <h2 className="flex min-w-0 flex-1 items-center gap-2 type-news-section text-text-primary">
        {logo}
        <span className="truncate">{children}</span>
      </h2>
      {trailing}
    </div>
  );
}

/**
 * The Leagues page (2026-10-19): the four league pages that were four tabs,
 * stacked on one, in the order the Leagues tab lists them. Each league is a
 * heading and one section — the newest story with a photo at full width,
 * four rows under it, and "See more" to the league's own News tab (the Top
 * 25 for college football, the league-wide conference page for the rest):
 * the same shape as a For you team section (Andy, 2026-10-19: "1 featured,
 * 4 standard, See more"). A league with nothing says so in its place rather
 * than vanishing from the order.
 */
function LeaguesPage({ pages }: { pages: LeaguePages["pages"] }) {
  return (
    <div className="flex flex-col gap-2">
      {LEAGUE_DISPLAY_ORDER.map((league, index) => {
        const stories = pages[league] ?? [];
        const wideId = leagueWideId(league);
        const seeMoreHref =
          league === "cfb"
            ? pollPath({ tab: "news" })
            : wideId !== undefined
              ? conferencePath({ league, id: wideId }, { tab: "news" })
              : undefined;
        return (
          <div key={league} className="flex flex-col gap-2">
            <Heading logo={<ConferenceLogo src={leagueLogoUrl(league)} name="" className="h-5 w-5" />}>
              {/* "NCAAF", as the Leagues tab and iOS print it; `displayName`
                  is the spoken form. */}
              {shortName(league)}
            </Heading>
            {stories.length === 0 ? (
              <Empty>No {shortName(league)} stories right now.</Empty>
            ) : (
              <StorySection stories={stories} seeMoreHref={seeMoreHref} priority={index === 0} />
            )}
          </div>
        );
      })}
    </div>
  );
}

function ForYou({
  leagues,
  teams,
  keys,
  visibleKeys,
  followedTeams,
  onReload,
}: {
  leagues: ReturnType<typeof useOnDemand<LeaguePages>>["state"];
  teams: ReturnType<typeof useOnDemand<ForYouTeams>>["state"];
  keys: string[];
  visibleKeys: string[];
  followedTeams: Team[];
  onReload: () => void;
}) {
  // The followed teams with stories, less the sheet's unchecked ones, in
  // the Teams tab's order (by school). The directory names them and draws
  // their marks; when it hasn't loaded, a story's own team tag names the
  // team and the league's logo bucket draws it, so a directory miss never
  // drops a section whose stories came.
  const byKey = useMemo(() => {
    const map = new Map<string, Team>();
    for (const team of followedTeams) {
      map.set(followKey({ league: team.league, teamId: team.id }), team);
    }
    return map;
  }, [followedTeams]);
  const pages = teams.status === "loaded" ? teams.value.teams : undefined;
  const shown = useMemo(() => new Set(visibleKeys), [visibleKeys]);
  const sections = useMemo(() => {
    if (!pages) return [];
    return Object.entries(pages)
      .flatMap(([key, stories]) => {
        const ref = parseFollowKey(key);
        if (!ref || !shown.has(key)) return [];
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
  }, [byKey, pages, shown]);

  // Failed only when all of it failed: the leagues, and the team feeds
  // where there were any to ask.
  const teamsFailed = teams.status === "failed";
  if (leagues.status === "failed" && (visibleKeys.length === 0 || teamsFailed)) {
    return <Failed onRetry={onReload} />;
  }
  if (leagues.status === "loading" || teams.status === "loading") {
    return <StorySectionSkeleton />;
  }
  const trending = leagues.status === "loaded" ? trendingStories(leagues.value.merged) : [];

  return (
    <div className="flex flex-col gap-2">
      {trending.length > 0 && (
        <>
          <Heading>Trending</Heading>
          <StorySection stories={trending} priority />
        </>
      )}
      {sections.map(({ key, ref, name, logo, stories }) => (
        <div key={key} className="flex flex-col gap-2">
          <Heading logo={<TeamLogo team={logo} teamName="" size="sm" className="h-5 w-5" />}>
            {name}
          </Heading>
          <StorySection stories={stories} seeMoreHref={teamPath(ref, { tab: "news" })} />
        </div>
      ))}
      {keys.length === 0 && (
        // Nobody followed still has Trending; this is where the team
        // sections would be.
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
      {trending.length === 0 && sections.length === 0 && keys.length > 0 && (
        <Empty>No stories right now.</Empty>
      )}
    </div>
  );
}
