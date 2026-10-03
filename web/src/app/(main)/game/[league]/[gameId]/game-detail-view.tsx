"use client";

// The game page (iOS GameDetailScreen): header on the card surface, then a
// tab row and the cards in the iOS order — line score, scoring, team stats,
// leaders. Live games poll every 1s through useLiveGame; a pre-game summary
// never demotes a live snapshot (the merge lives in the hook).
//
// **Summary / News / Plays / Box score / H2H**, and a tab only exists where its data
// does: a game ESPN hasn't filled in shows Summary and the series alone. Plays
// sits in the middle because chronology comes before rosters, and the Drives
// card lives inside it: leaving it on Summary would print the same rows in two
// tabs.
//
// H2H reads the pushed row rather than the summary, so it is offered from the
// first frame — which is the point: before kickoff it is the only other tab
// there is, and "who usually wins this" is the pre-game question. That does
// mean a pre-kick page now shows a tab row where it deliberately showed none;
// a row of two real answers is not the chrome-saying-nothing that rule was
// written against. News (E26) is the same kind of tab: the two teams' own
// feeds, fetched when it first opens, second like every entity page's.
//
// Desktop splits that into two columns: the game itself on the left, and
// the context that surrounds it — where it's played, who showed up, what
// it does to the tables — in a rail on the right. The iPhone's single
// column keeps the same reading order, so the rail's cards land after the
// drives rather than between them; on a phone that's still "the game,
// then the context".

import type { ConferenceStandingsGroup, GameDetail } from "@/lib/types";
import { useEffect, useRef, useState } from "react";
import { useLiveGame } from "@/lib/hooks/use-live-game";
import { useOnDemand } from "@/lib/hooks/use-on-demand";
import { getHeadToHead, getTeamsNews } from "@/lib/api";
import { StoryListCard, StoryListCardSkeleton } from "@/components/story-list-card";
import { forYou } from "@/lib/espn/news";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import {
  SlateToggleChip,
} from "@/components/slate-control-row";
import { periodFormat, scoringCardTitle, seasonYear } from "@/lib/leagues";
import { isLiveStatus, showsScores } from "./game-status";
import { GameHeader } from "./game-header";
import { CompactGameHeader } from "./compact-game-header";
import { cn } from "@/lib/utils";
import {
  GameInfoCard,
  VenueCard,
  gameInfoHasContent,
  venueHasContent,
} from "./game-info-cards";
import { GetTheAppCard } from "@/components/get-the-app";
import {
  DriveGamecastCard,
  ShotGamecastCard,
} from "./live-situation-card";
import { currentShotMap, shotMapGamecast } from "@/lib/gamecast";
import { allowsShootout } from "@/lib/period-label";

import { LineScoreCard } from "./line-score-card";
import { WinProbabilityCard } from "./win-probability-card";
import { ScoringPlaysCard } from "./scoring-plays-card";
import { TeamStatsCard, hasTeamStats } from "./team-stats-card";
import { LeadersCard } from "./leaders-card";
import {
  MatchupStandingsCard,
  matchupStandingsHasContent,
} from "./matchup-standings-card";
import { BoxScoreList } from "./box-score-list";
import { DrivePlayList, PeriodPlayList } from "./play-lists";
import { HeadToHeadPane } from "./head-to-head-pane";
import { DetailCard } from "./detail-card";
import { StoryRow } from "@/components/story-row";
import { storyForGame, storyKindTitle } from "@/lib/news";

interface GameDetailViewProps {
  initialData: GameDetail;
  /** Current-season conference standings; null when the fetch missed or
   * was skipped — a miss just hides the matchup card. */
  standings: ConferenceStandingsGroup[] | null;
}

export function GameDetailView({
  initialData,
  standings: fetchedStandings,
}: GameDetailViewProps) {
  const data = useLiveGame(initialData.game.id, initialData);
  // The summary's own copy of the two conferences wins where it came (iOS
  // `currentStandings`, 2026-09-21); the fetched tables are the fallback.
  const standings: ConferenceStandingsGroup[] | null =
    data.matchupStandings && data.matchupStandings.length > 0
      ? data.matchupStandings
      : fetchedStandings;
  const { game } = data;
  const scores = showsScores(game);
  const [tab, setTab] = useState("summary");
  // Two answers to one question, the Games tabs' own control language: All
  // plays or Scoring, so turning one on turns the other off.
  const [scoringOnly, setScoringOnly] = useState(false);

  const hasLinescores =
    (game.awayTeam.linescores?.length ?? 0) > 0 ||
    (game.homeTeam.linescores?.length ?? 0) > 0;
  const scoringPlays = data.scoringPlays ?? [];
  const leaders = data.leaders ?? [];
  const drives = data.drives ?? [];
  const plays = data.plays ?? [];
  const boxScore = data.boxScore ?? [];

  // Football's plays live inside its drives; every other league's arrive
  // flat. Which list the Plays tab renders follows from that.
  const hasPlays = drives.length > 0 || plays.length > 0;
  // Whether a series is even askable. Both sides have to be named — an id is
  // what the meetings are filtered by — and a team cannot play itself.
  const awayId = game.awayTeam.team.id;
  const homeId = game.homeTeam.team.id;
  const hasHeadToHead = awayId !== "" && homeId !== "" && awayId !== homeId;
  const tabs: HeroTab[] = [
    { id: "summary", label: "Summary" },
    ...(hasHeadToHead ? [{ id: "news", label: "News" }] : []),
    ...(hasPlays ? [{ id: "plays", label: "Plays" }] : []),
    ...(boxScore.length > 0 ? [{ id: "boxScore", label: "Box score" }] : []),
    ...(hasHeadToHead ? [{ id: "h2h", label: "H2H" }] : []),
  ];
  // A tab whose data went away between polls falls back rather than
  // rendering an empty pane.
  const activeTab = tabs.some((entry) => entry.id === tab) ? tab : "summary";

  // The series is fetched when its tab is first opened, not with the page —
  // twenty requests is a lot to spend on a tab most visits never reach.
  // Latched on the tap that opens it rather than watched for afterwards: once
  // asked for it stays asked for, so flipping back costs nothing.
  const [seriesRequested, setSeriesRequested] = useState(false);
  const [newsRequested, setNewsRequested] = useState(false);
  const selectTab = (id: string) => {
    setTab(id);
    if (id === "h2h") setSeriesRequested(true);
    if (id === "news") setNewsRequested(true);
  };
  const series = useOnDemand(
    seriesRequested ? `${game.league}:${game.id}` : undefined,
    () => getHeadToHead(game.league, game.id)
  );
  const newsFeed = useOnDemand(
    newsRequested ? `${game.league}:${game.id}` : undefined,
    () =>
      getTeamsNews([
        { league: game.league, teamId: awayId },
        { league: game.league, teamId: homeId },
      ])
  );
  const hasScoringPlays =
    drives.length > 0
      ? drives.some((drive) => (drive.plays ?? []).some((p) => p.isScoringPlay))
      : plays.some((play) => play.isScoringPlay);

  // Past-season games (reached by direct link) must not wear the current
  // season's standings — the fetch is always the current tables.
  // Read on **this game's league's** clock: a college-football rollover
  // would call June "next season" while the Stanley Cup was still being
  // played for, and February the same for the NFL.
  const isCurrentSeason =
    game.scheduledAt !== "" &&
    seasonYear(game.league, new Date(game.scheduledAt)) ===
      seasonYear(game.league);
  const standingsVisible =
    standings !== null &&
    isCurrentSeason &&
    matchupStandingsHasContent(
      game.awayTeam.team,
      game.homeTeam.team,
      standings
    );

  const venueVisible = venueHasContent(game, data);
  const infoVisible = gameInfoHasContent(game, data, standings);
  // "Scoring" in football, "Goals" in hockey, and no card at all in
  // basketball — ~98 buckets a game is the box score with worse formatting.
  const scoringTitle = scoringCardTitle(game.league);
  // The court or rink Gamecast, live games only: the color budget's surface
  // exception is "only ever drawn while a game is live", and a final keeps
  // the page it had. Undefined in football, whose card is the drive, and
  // wherever the feed has nothing to draw.
  const shotGamecast = (() => {
    if (!isLiveStatus(game.status)) return undefined;
    const plays = data.plays ?? [];
    const shootout = allowsShootout(game);
    const map = currentShotMap(game, plays, shootout);
    const content = shotMapGamecast(game, plays, shootout);
    return map && content ? { map, content } : undefined;
  })();

  const showsTabs = tabs.length > 1;
  // The strip's top sits this far above the sentinel (its negative margin).
  const [stickSentinel, stuck] = useStuck(showsTabs ? 52 : 44);
  // Who has the ball: the drive in progress, live only. Never the pushed
  // row's `possession`, which froze when the page was opened (iOS
  // `GameHeaderState.possessionTeamId`).
  const possessionTeamId = isLiveStatus(game.status)
    ? data.situation?.possessionTeamId
    : undefined;

  // The game's own story (iOS E25, docs/news.md N2 and N3): the recap once
  // final, the preview before kickoff, nothing live. It rode in with the
  // summary, so the card costs no request of its own.
  const story = storyForGame(data.article, game.id, game.status);
  const storyCard = story && (
    <DetailCard title={storyKindTitle(story.kind)}>
      <StoryRow story={story} />
    </DetailCard>
  );

  return (
    <div className="flex w-full flex-col">
      {/* The header sits on the card surface, and the tab row with it —
          headers match the cards on every entity page. */}
      <GameHeader game={game} possessionTeamId={possessionTeamId} />
      {/* Siblings of the header, not wrapped with it: `position: sticky`
          only travels inside its parent's box, and this page's container
          spans the content the strip has to pin over. */}
      <div ref={stickSentinel} aria-hidden="true" className="h-px -mb-px" />
      <div
        className={cn(
          "sticky top-14 z-20 sm:top-16",
          // The compact row overlays the header's last 44px, invisible,
          // until the strip pins; with tabs it also tucks 8px further up
          // to cover the header card's bottom corners.
          showsTabs ? "-mt-[52px]" : "-mt-11"
        )}
      >
        <div
          className={cn(
            "transition-opacity duration-150",
            stuck
              ? "bg-bg-card opacity-100"
              : "pointer-events-none opacity-0",
            stuck && !showsTabs && "border-b border-divider"
          )}
        >
          <CompactGameHeader game={game} possessionTeamId={possessionTeamId} />
        </div>
        {showsTabs && (
          // The nav bar's hairline along the bottom, so the pinned row has
          // the same edge over the content scrolling under it (iOS,
          // 2026-10-02). The card's rounded foot only while it sits on the
          // header; pinned, it runs square.
          <div
            className={cn(
              "border-b border-divider bg-bg-card",
              !stuck && "rounded-b-[10px]"
            )}
          >
            <HeroTabBar tabs={tabs} selected={activeTab} onSelect={selectTab} />
          </div>
        )}
      </div>

      <div className="mt-2 flex flex-col gap-2">

      {activeTab === "summary" && (
        // Desktop splits the summary into two columns: the game itself on
        // the left, and the context that surrounds it — where it's played,
        // who showed up, what it does to the tables — in a rail on the
        // right. The iPhone's single column keeps the same reading order.
        <div className="grid w-full gap-2 lg:grid-cols-[minmax(0,1fr)_320px] lg:items-start lg:gap-4">
          <div className="flex min-w-0 flex-col gap-2">
            {/* A final leads with its recap, FotMob's match report on Facts. */}
            {story?.kind === "recap" && storyCard}
            {/* The Gamecast leads while a game is live: the down, the spot
                and the last play are what the page is being opened for at
                3:30 on a Saturday. Football's is built from the drive in
                progress, which ESPN drops at final — so it retires itself. */}
            {data.situation ? (
              <DetailCard title="Current drive">
                <DriveGamecastCard game={game} situation={data.situation} />
              </DetailCard>
            ) : (
              shotGamecast && (
                // Basketball and hockey: the same card over this period's
                // shots (iOS, 2026-09-27).
                <DetailCard
                  title={`Current ${periodFormat(game.league).longName.toLowerCase()}`}
                >
                  <ShotGamecastCard
                    game={game}
                    content={shotGamecast.content}
                    map={shotGamecast.map}
                  />
                </DetailCard>
              )
            )}
            {hasLinescores && <LineScoreCard game={game} />}
            {/* ESPN's predictor before kickoff, the per-play value after
                it. Absent in hockey, whose payload has neither. */}
            {data.winProbability && (
              <WinProbabilityCard
                probability={data.winProbability}
                isFinal={game.status === "complete"}
                awayTeam={game.awayTeam}
                homeTeam={game.homeTeam}
              />
            )}
            {scoringPlays.length > 0 && scoringTitle && (
              <ScoringPlaysCard
                plays={scoringPlays}
                title={scoringTitle}
                game={game}
              />
            )}
            {scores && hasTeamStats(data.awayStats, data.homeStats) && (
              <TeamStatsCard
                awayTeam={game.awayTeam}
                homeTeam={game.homeTeam}
                awayStats={data.awayStats}
                homeStats={data.homeStats}
              />
            )}
            {leaders.length > 0 && (
              <LeadersCard
                leaders={leaders}
                awayTeam={game.awayTeam}
                homeTeam={game.homeTeam}
                league={game.league}
              />
            )}
          </div>

          <div className="flex min-w-0 flex-col gap-2">
            {/* One card was answering two questions: when and where to
                watch is one, the ground it's played on is another. Pre-kick
                every section on the left is empty, so the pair carries the
                whole "what do I need to know" load — but the questions
                outlive the kickoff, so both stay once a game starts. */}
            {infoVisible && (
              <GameInfoCard game={game} detail={data} standings={standings} />
            )}
            {/* Pre-game the preview follows Game info: when and where to
                watch is still the first question. */}
            {story?.kind === "preview" && storyCard}
            {venueVisible && <VenueCard game={game} detail={data} />}
            {standingsVisible && (
              <MatchupStandingsCard
                away={game.awayTeam.team}
                home={game.homeTeam.team}
                standings={standings}
              />
            )}
            {/* Last in the rail, and last in the phone's single column: a
                game page is where a shared link lands (the OpenGraph card,
                2026-09-09), so this is the one screen whose visitor may
                never have heard of the app — and the foot of the page they
                just read is where saying so is earned rather than sold. */}
            <GetTheAppCard />
          </div>
        </div>
      )}

      {activeTab === "plays" && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <SlateToggleChip
              title="All plays"
              isOn={!scoringOnly}
              hint="Shows every play"
              onToggle={() => setScoringOnly(false)}
            />
            <SlateToggleChip
              title="Scoring"
              isOn={scoringOnly}
              hint="Shows only the plays that scored"
              onToggle={() => setScoringOnly(true)}
            />
          </div>
          {scoringOnly && !hasScoringPlays ? (
            <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
              No scoring plays yet.
            </section>
          ) : drives.length > 0 ? (
            <DrivePlayList
              drives={drives}
              game={game}
              scoringOnly={scoringOnly}
            />
          ) : (
            <PeriodPlayList
              plays={plays}
              game={game}
              scoringOnly={scoringOnly}
            />
          )}
        </div>
      )}

      {activeTab === "boxScore" && (
        <BoxScoreList boxScore={boxScore} game={game} />
      )}

      {activeTab === "news" &&
        (newsFeed.state.status === "failed" ? (
          <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
            <p className="type-team-name text-text-secondary">Couldn&apos;t load the news.</p>
            <button
              type="button"
              onClick={newsFeed.reload}
              className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
            >
              Retry
            </button>
          </section>
        ) : newsFeed.state.status === "loading" ? (
          <StoryListCardSkeleton />
        ) : (
          // The game's own recap or preview folds in with the feeds —
          // the Summary tab's card, listed with the rest of the matchup.
          (() => {
            const stories = forYou([story ? [story] : [], newsFeed.state.value]);
            return stories.length > 0 ? (
              <StoryListCard stories={stories} />
            ) : (
              <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
                No stories about this matchup right now.
              </section>
            );
          })()
        ))}

      {activeTab === "h2h" && (
        <HeadToHeadPane
          away={game.awayTeam.team}
          home={game.homeTeam.team}
          state={series.state}
          onRetry={series.reload}
        />
      )}
      </div>
    </div>
  );
}

/** The nav bar's height: `h-14`, and `sm:h-16` from 640px up. */
function navBarHeight(): number {
  return window.matchMedia("(min-width: 640px)").matches ? 64 : 56;
}

/**
 * Whether the tab strip has pinned under the nav bar — what fades the
 * compact scoreboard in (iOS hands the bar its compact score at the same
 * moment). Watched off a sentinel just above the strip, which sits
 * `offset` px below the strip's own top.
 */
function useStuck(offset: number) {
  const ref = useRef<HTMLDivElement>(null);
  const [stuck, setStuck] = useState(false);
  useEffect(() => {
    const sentinel = ref.current;
    if (!sentinel) return;
    let observer: IntersectionObserver | undefined;
    const observe = () => {
      observer?.disconnect();
      observer = new IntersectionObserver(
        ([entry]) => {
          // Out of the band *above* it, not below the fold.
          const top = entry.rootBounds?.top ?? 0;
          setStuck(!entry.isIntersecting && entry.boundingClientRect.top < top);
        },
        { rootMargin: `-${navBarHeight() + offset}px 0px 0px 0px` }
      );
      observer.observe(sentinel);
    };
    observe();
    const media = window.matchMedia("(min-width: 640px)");
    media.addEventListener("change", observe);
    return () => {
      media.removeEventListener("change", observe);
      observer?.disconnect();
    };
  }, [offset]);
  return [ref, stuck] as const;
}
