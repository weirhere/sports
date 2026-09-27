// A story, read on StatSide (iOS `StoryReader`, E25, docs/news.md N4 to N7):
// the photo edge to edge where ESPN sent one (2026-09-27, FotMob's article
// detail), the headline, who wrote it and exactly when, the dek, the game's own score
// row, the text, then the teams it's about.
//
// **One divergence from iOS, and it is the URL.** The app carries a story
// in memory through its navigation; a URL has to rebuild the page from
// nothing on a shared link or a refresh. So the page asks ESPN's content
// API for the story by id — it serves the summary's recaps as well as a
// team feed's stories — and the score row is always a link, since a reader
// who arrived from a link has no game page behind them to go back to.

import { StoryPhoto } from "@/components/story-photo";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { conferenceTeams, gameSummary } from "@/lib/espn";
import { EspnApiError } from "@/lib/espn/provider";
import { newsStoryById } from "@/lib/espn/news-provider";
import { parseLeague, type League } from "@/lib/leagues";
import { storyKindTitle, type NewsStory } from "@/lib/news";
import { gamePath } from "@/lib/routes";
import type { Game, Team } from "@/lib/types";
import { CardHeader } from "@/components/card-header";
import { StoryMeta } from "@/components/story-meta";
import { GameMatchupRow, gameRowLabel } from "@/components/next-game-card";
import { StoryTeamsCard } from "./story-teams-card";

interface PageProps {
  params: Promise<{ league: string; storyId: string }>;
}

async function loadStory(league: League, storyId: string): Promise<NewsStory | undefined> {
  try {
    return await newsStoryById(league, storyId);
  } catch (err) {
    // An id ESPN doesn't know is a 404; ESPN being down is the error page.
    if (err instanceof EspnApiError && err.status < 500) return undefined;
    throw err;
  }
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { league: leagueParam, storyId } = await params;
  const league = parseLeague(leagueParam);
  if (!league || !/^\d+$/.test(storyId)) return { title: "Story | StatSide" };
  const story = await loadStory(league, storyId).catch(() => undefined);
  return story
    ? { title: `${story.headline} | StatSide`, description: story.dek }
    : { title: "Story | StatSide" };
}

export default async function StoryPage({ params }: PageProps) {
  const { league: leagueParam, storyId } = await params;
  const league = parseLeague(leagueParam);
  if (!league || !/^\d+$/.test(storyId)) notFound();
  const story = await loadStory(league, storyId);
  if (!story?.body) notFound();

  // Both ride along and both may miss: a game the summary can't find drops
  // the score row, and a directory that didn't answer drops the follow rows.
  const [gameResult, directoryResult] = await Promise.allSettled([
    story.gameId ? gameSummary(league, story.gameId) : Promise.resolve(undefined),
    story.teams.length > 0 ? conferenceTeams(league) : Promise.resolve([]),
  ]);
  const game: Game | undefined =
    gameResult.status === "fulfilled" ? gameResult.value?.game : undefined;
  const directory = directoryResult.status === "fulfilled" ? directoryResult.value : [];
  // A tag the directory can't place (a team outside the league's top
  // division, say) is left out rather than drawn without a crest.
  const teams = story.teams
    .map((tag) => directory.flatMap((group) => group.teams).find((team) => team.id === tag.id))
    .filter((team): team is Team => team !== undefined);

  return (
    <article className="mx-auto flex w-full max-w-[38rem] flex-col gap-2">
      {/* The header sits on the card surface like the game page's. */}
      <header className="card-surface flex flex-col">
        {story.imageUrl && (
          <StoryPhoto
            url={story.imageUrl}
            sizes="(min-width: 640px) 608px, 100vw"
            priority
            className="aspect-video w-full"
          />
        )}
        <div className="flex flex-col gap-2 px-4 py-5">
          <p className="type-meta-em text-text-secondary">{storyKindTitle(story.kind)}</p>
          <h1 className="type-hero-title text-text-primary">{story.headline}</h1>
          <StoryMeta story={story} time="exact" />
          {story.dek && <p className="type-team-name text-text-secondary">{story.dek}</p>}
        </div>
      </header>

      {/* `NextGameCard`'s recipe: a header over the matchup row itself. */}
      {game && (
        <section className="card-surface">
          <CardHeader title="Game" />
          <Link
            href={gamePath(game)}
            aria-label={gameRowLabel(game)}
            className="block transition-colors hover:bg-bg-header"
            suppressHydrationWarning
          >
            <GameMatchupRow game={game} />
          </Link>
        </section>
      )}

      {/* The text in the site's reading treatment (`Prose`): 15px on a
          relaxed leading, the measure capped by the column. Subheads take
          the emphasis weight, as the app's do. */}
      <section className="card-surface flex flex-col gap-3 px-4 py-4">
        {story.body.map((block, index) =>
          block.kind === "heading" ? (
            <h2 key={index} className="pt-1 type-team-name-em text-text-primary">
              {block.text}
            </h2>
          ) : (
            <p key={index} className="text-[15px] leading-relaxed text-text-primary">
              {block.text}
            </p>
          )
        )}
      </section>

      {teams.length > 0 && <StoryTeamsCard teams={teams} />}
    </article>
  );
}
