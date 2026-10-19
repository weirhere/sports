// The web twin of iOS `NewsTests` (sportsTests/NewsTests.swift), over the
// same payloads: the NBA summary's recap, a Knicks `/news?team=18` feed and
// one content-API story, fetched 2026-09-27.

import { describe, it, expect } from "vitest";
import summaryJson from "./espn/__fixtures__/nba-summary-article.json";
import feedJson from "./espn/__fixtures__/nba-team-news.json";
import storyJson from "./espn/__fixtures__/nba-news-story.json";
import overviewJson from "./espn/__fixtures__/nba-athlete-overview.json";
import searchJson from "./espn/__fixtures__/search-knicks.json";
import {
  gameIdForStoryLink,
  leagueForStoryLink,
  transformStorySearch,
} from "./espn/athlete-search";
import type { EspnSearchResponse } from "./espn/types";
import {
  forYou,
  playerFeed,
  type EspnAthleteOverviewNews,
  isFlooded,
  leagueFeed,
  toppedUp,
  newsStory,
  storyImage,
  storyUrl,
  teamFeed,
  teamNewsUrl,
  type EspnNewsArticle,
  type EspnNewsFeed,
  type EspnNewsHeadlines,
} from "./espn/news";
import {
  attribution,
  exactTime,
  isFocused,
  relativeTime,
  storyBlocks,
  arrangedStories,
  storyForGame,
  storyKind,
  type NewsStory,
  isTransaction,
  latestStories,
  transferStories,
  trendingStories,
  LATEST_CAP,
} from "./news";

const recap = newsStory(summaryJson.article as EspnNewsArticle, "nba")!;

describe("the summary's own story (N2, N3)", () => {
  it("reads the recap whole", () => {
    expect(recap.kind).toBe("recap");
    expect(recap.gameId).toBe("401810871");
    expect(recap.attribution).toBe("AP");
    expect(recap.teams.map((team) => team.id)).toEqual(["17", "18"]);
    expect(recap.dek?.startsWith("Karl-Anthony Towns")).toBe(true);
    expect((recap.body ?? []).length).toBeGreaterThan(5);
  });

  it("tidies the dateline and ends at the wire's rule", () => {
    const body = recap.body ?? [];
    expect(body[0]).toMatchObject({ kind: "paragraph" });
    expect(body[0].text.startsWith("NEW YORK — Karl-Anthony Towns had 26")).toBe(true);
    expect(body).toContainEqual({ kind: "heading", text: "Up next" });
    expect(body[body.length - 1]).toEqual({
      kind: "paragraph",
      text: "Nets: Visit the Sacramento Kings on Sunday.",
    });
    expect(body.some((block) => /<|apnews\.com/.test(block.text))).toBe(false);
  });

  it("shows the recap only once final, and only for its own game", () => {
    expect(storyForGame(recap, "401810871", "complete")?.kind).toBe("recap");
    expect(storyForGame(recap, "401810871", "scheduled")).toBeUndefined();
    expect(storyForGame(recap, "401810871", "in_progress")).toBeUndefined();
    expect(storyForGame(recap, "1", "complete")).toBeUndefined();
    const preview = { ...recap, kind: "preview" as const };
    expect(storyForGame(preview, "401810871", "scheduled")?.kind).toBe("preview");
    expect(storyForGame(preview, "401810871", "complete")).toBeUndefined();
  });
});

describe("the team feed (N9, N10)", () => {
  const feed = feedJson as EspnNewsFeed;
  const stories = teamFeed(feed, "18", "nba");

  it("keeps only stories about the team", () => {
    // 25 in the feed, all tagged with the Knicks; 8 about them.
    expect(feed.articles?.length).toBe(25);
    expect(stories).toHaveLength(8);
    expect(stories.every((story) => isFocused(story, "18"))).toBe(true);
    expect(stories.every((story) => story.body === undefined)).toBe(true);
  });

  it("sorts newest first", () => {
    const times = stories.map((story) => story.published ?? "");
    expect([...times].sort().reverse()).toEqual(times);
  });

  it("drops video and tickets", () => {
    expect(storyKind("Media")).toBeUndefined();
    expect(storyKind("Eticket")).toBeUndefined();
    expect(storyKind("HeadlineNews")).toBe("headline");
  });

  it("calls a roundup a roundup", () => {
    const tagged = (ids: string[]): NewsStory => ({
      id: "1",
      kind: "story",
      league: "nba",
      headline: "h",
      teams: ids.map((id) => ({ id, name: id })),
    });
    expect(isFocused(tagged(["18"]), "18")).toBe(true);
    expect(isFocused(tagged(["18", "17"]), "18")).toBe(true);
    expect(isFocused(tagged(["18", "17", "2"]), "18")).toBe(false);
    expect(isFocused(tagged(["17"]), "18")).toBe(false);
  });

  it("asks the hosts that answer any User-Agent", () => {
    expect(teamNewsUrl("cfb", "130")).toBe(
      "https://site.web.api.espn.com/apis/site/v2/sports/football/college-football/news?team=130&limit=25"
    );
    expect(storyUrl("50039929")).toBe(
      "https://content.core.api.espn.com/v1/sports/news/50039929"
    );
  });
});

describe("the reader (N4)", () => {
  it("reads the content API's paragraphs", () => {
    const article = (storyJson as EspnNewsHeadlines).headlines![0];
    const story = newsStory(article, "nba")!;
    expect(story.body).toHaveLength(5);
    expect(story.body?.[0]).toEqual({
      kind: "paragraph",
      text: "New York Knicks star guard Jalen Brunson is ready for the 2026-27 season after acknowledging that he underwent left wrist surgery.",
    });
    expect(story.attribution).toBe("ESPN");
  });

  it("strips tags and decodes entities", () => {
    const html =
      "<p>A &amp; B&#8217;s &bogus; &#x2014;</p><p> </p>" +
      '<h2>Head <a href="x">line</a></h2><p>C<img src=\'a\'/></p>';
    expect(storyBlocks(html)).toEqual([
      { kind: "paragraph", text: "A & B’s &bogus; —" },
      { kind: "heading", text: "Head line" },
      { kind: "paragraph", text: "C" },
    ]);
  });

  it("prefers the byline", () => {
    expect(attribution("Zach Kram", "ESPN")).toBe("Zach Kram");
    expect(attribution(undefined, "Associated Press")).toBe("AP");
    expect(attribution(" ", undefined)).toBeUndefined();
  });
});

describe("timestamps (N7)", () => {
  const now = new Date("2026-09-27T20:00:00Z"); // 4 PM Eastern
  const zone = "America/New_York";
  const relative = (iso: string) => relativeTime(iso, now, zone);

  it("is relative in a list", () => {
    expect(relative("2026-09-27T19:59:30Z")).toBe("Just now");
    expect(relative("2026-09-27T19:48:00Z")).toBe("12m ago");
    expect(relative("2026-09-27T13:00:00Z")).toBe("7h ago");
    // 11 PM Eastern the night before is yesterday, whatever UTC says.
    expect(relative("2026-09-27T03:00:00Z")).toBe("Yesterday");
    expect(relative("2026-09-24T12:00:00Z")).toBe("Sep 24");
    expect(relative("2025-11-05T12:00:00Z")).toBe("Nov 5, 2025");
  });

  it("is exact in the reader", () => {
    expect(exactTime("2026-09-27T19:44:00Z", zone)).toBe("Sep 27, 2026 at 3:44 PM");
  });
});

describe("the News tab (E26)", () => {
  it("puts a league's previews last", () => {
    // ESPN's college-football feed on 2026-09-27 was 50 AP previews
    // published within four minutes. Newer isn't enough to lead.
    const feed: EspnNewsFeed = {
      articles: [
        { id: 1, type: "Preview", headline: "Next week", published: "2026-09-27T19:47:00Z" },
        { id: 2, type: "Story", headline: "Older story", published: "2026-09-27T12:00:00Z" },
        { id: 3, type: "Media", headline: "A video", published: "2026-09-27T20:00:00Z" },
        { id: 4, type: "HeadlineNews", headline: "Newest news", published: "2026-09-27T18:00:00Z" },
      ],
    };
    expect(leagueFeed(feed, "cfb").map((story) => story.id)).toEqual(["4", "2", "1"]);
  });

  it("merges For you once each, newest first", () => {
    const story = (id: string, published: string): NewsStory => ({
      id,
      kind: "recap",
      league: "nba",
      headline: id,
      published,
      teams: [],
    });
    // A recap tags both teams, and both are followed.
    const knicks = [story("recap", "2026-09-27T03:00:00Z"), story("knicks", "2026-09-26T12:00:00Z")];
    const nets = [story("nets", "2026-09-27T12:00:00Z"), story("recap", "2026-09-27T03:00:00Z")];
    expect(forYou([knicks, nets]).map((entry) => entry.id)).toEqual(["nets", "recap", "knicks"]);
  });
});

describe("the preview flood (E26)", () => {
  const story = (id: string, kind: NewsStory["kind"], published: string): NewsStory => ({
    id,
    kind,
    league: "cfb",
    headline: id,
    published,
    teams: [],
  });
  // The 2026-09-27 feed: nothing but next week's previews.
  const flood = Array.from({ length: 12 }, (_, i) =>
    story(`p${i + 1}`, "preview", `2026-09-27T19:4${(i + 1) % 10}:00Z`)
  );

  it("knows a flood from a news day", () => {
    expect(isFlooded(flood)).toBe(true);
    expect(
      isFlooded(Array.from({ length: 10 }, (_, i) => story(`s${i}`, "story", "2026-09-27T12:00:00Z")))
    ).toBe(false);
  });

  it("tops a flood up with the ranked teams, previews still last", () => {
    const michigan = [story("recap", "recap", "2026-09-27T03:00:00Z"), story("mich", "headline", "2026-09-26T12:00:00Z")];
    const iowa = [story("recap", "recap", "2026-09-27T03:00:00Z"), story("iowa-preview", "preview", "2026-09-27T20:00:00Z")];
    expect(toppedUp(flood.slice(0, 2), [michigan, iowa]).map((entry) => entry.id)).toEqual([
      "recap",
      "mich",
      "iowa-preview",
      "p2",
      "p1",
    ]);
  });
});

describe("a player's News tab (E26)", () => {
  it("reads the athlete overview's own list, less the video", () => {
    const dto = overviewJson as EspnAthleteOverviewNews;
    const stories = playerFeed(dto, "nba");
    // Brunson's 13, 5 of them video.
    expect(dto.news).toHaveLength(13);
    expect(stories).toHaveLength(8);
    const times = stories.map((story) => story.published ?? "");
    expect([...times].sort().reverse()).toEqual(times);
  });
});

describe("Search's News scope (E26)", () => {
  it("reads the article group beside the people", () => {
    // "knicks" on 2026-09-27: ten articles, one a New York story filed
    // under the NFL. Clips and replays are video and never map.
    const stories = transformStorySearch(searchJson as EspnSearchResponse);
    expect(stories).toHaveLength(10);
    expect(stories[0]).toMatchObject({
      id: "50039929",
      kind: "headline",
      league: "nba",
      attribution: "AP",
    });
    expect(stories.some((story) => story.league === "nfl")).toBe(true);
    expect(stories.every((story) => story.published)).toBe(true);
  });

  it("drops leagues the app doesn't cover", () => {
    expect(leagueForStoryLink("https://www.espn.com/college-football/story/_/id/1/x")).toBe("cfb");
    expect(leagueForStoryLink("https://www.espn.com/soccer/story/_/id/1/x")).toBeUndefined();
    expect(leagueForStoryLink("not a url")).toBeUndefined();
    // AP's recaps and previews use ESPN's older paths.
    const recap = "http://www.espn.com/ncf/recap?gameId=401858463";
    expect(leagueForStoryLink(recap)).toBe("cfb");
    expect(gameIdForStoryLink(recap)).toBe("401858463");
  });
});

describe("photos (2026-09-27)", () => {
  it("leads with the header photo", () => {
    const video = { type: "Media", url: "https://e.com/still.jpg" };
    const header = { type: "header", url: "https://e.com/header.jpg" };
    const plain = { url: "https://e.com/plain.jpg" };
    expect(storyImage([video, plain, header])).toBe(header.url);
    // No header: a photo before a video's still; only a still beats nothing.
    expect(storyImage([video, plain])).toBe(plain.url);
    expect(storyImage([video])).toBe(video.url);
    expect(storyImage([{ type: "header" }])).toBeUndefined();
    expect(storyImage(undefined)).toBeUndefined();
    // ESPN's generated matchup cards 404; a recap with only one has none.
    const stitcher = {
      type: "header",
      url: "https://s.espncdn.com/stitcher/sports/football/college-football/events/401858463.png?templateId=espn",
    };
    expect(storyImage([stitcher])).toBeUndefined();
    expect(storyImage([stitcher, plain])).toBe(plain.url);
  });

  it("leads a section with a photo, the rest in order", () => {
    const story = (id: string, imageUrl?: string): NewsStory => ({
      id,
      kind: "story",
      league: "nba",
      headline: id,
      teams: [],
      imageUrl,
    });
    const list = [story("a"), story("b"), story("c", "x.jpg"), story("d"), story("e"), story("f")];
    expect(arrangedStories(list).map((entry) => entry.id)).toEqual(["c", "a", "b", "d", "e"]);
    expect(arrangedStories([story("a"), story("b")]).map((entry) => entry.id)).toEqual(["a", "b"]);
  });

  it("keeps a feed item's photo", () => {
    const feed: EspnNewsFeed = {
      articles: [
        {
          id: 1,
          type: "HeadlineNews",
          headline: "With a photo",
          images: [{ type: "header", url: "https://a.espncdn.com/photo/x.jpg" }],
        },
      ],
    };
    expect(leagueFeed(feed, "nba")[0].imageUrl).toBe("https://a.espncdn.com/photo/x.jpg");
  });
});

describe("Transfers and the For you sheet (2026-10-19)", () => {
  const headline = (
    text: string,
    extra: Partial<Pick<NewsStory, "kind" | "dek" | "topics">> = {}
  ): NewsStory => ({
    id: text,
    kind: "headline",
    league: "nba",
    headline: text,
    teams: [],
    ...extra,
  });

  it("marks trades, signings and waivers by their words", () => {
    // The 2026-10-19 probe's headlines, none of which ESPN tagged.
    expect(isTransaction(headline("Knicks waive Bruce Brown, keep James Wiseman ahead of opener"))).toBe(true);
    expect(isTransaction(headline("Still awaiting trade, Connor Hellebuyck could rejoin Jets when suspension ends"))).toBe(true);
    expect(isTransaction(headline("Bears agree to terms with veteran kicker"))).toBe(true);
    expect(isTransaction(headline("Four-star QB commits to Ohio State"))).toBe(true);
    expect(isTransaction(headline("Star receiver enters the transfer portal"))).toBe(true);
    expect(isTransaction(headline("Towns, Knicks finalize four-year extension"))).toBe(true);
    // The dek counts too.
    expect(isTransaction(headline("Roster moves", { dek: "The Jets released their starting kicker" }))).toBe(true);
    // Whole words: "design" and "signal" are not "sign".
    expect(isTransaction(headline("Designs on a title: inside the Thunder's offseason"))).toBe(false);
    expect(isTransaction(headline("A signal win for the Celtics' bench"))).toBe(false);
    // "deal" is every game story's word.
    expect(isTransaction(headline("Judging overreactions to NFL Week 6: Regretting Daniel Jones, A.J. Brown deals?"))).toBe(false);
  });

  it("never counts a game story", () => {
    expect(isTransaction(headline("Jets trade blows with Bills in overtime thriller", { kind: "recap" }))).toBe(false);
    expect(isTransaction(headline("Preview: Lakers sign off on new-look rotation", { kind: "preview" }))).toBe(false);
  });

  it("counts only the topics that can't mean anything else", () => {
    expect(isTransaction(headline("Deadline day", { topics: ["nba trade deadline"] }))).toBe(true);
    expect(isTransaction(headline("Portal watch", { topics: ["transfer portal"] }))).toBe(true);
    // ESPN hangs "nba free agency" on a stat column; the tag alone doesn't
    // make one.
    expect(
      isTransaction(
        headline("The stat that could swing every NBA team's season", {
          topics: ["daily", "nba free agency"],
        })
      )
    ).toBe(false);
    // The fixture's topics come through the mapper, lowercased.
    const stories = (feedJson as EspnNewsFeed).articles!
      .map((article) => newsStory(article, "nba"))
      .filter((story): story is NewsStory => story !== undefined);
    const graded = stories.find((story) => story.id === "48957095")!;
    expect(graded.topics).toContain("nba free agency");
    expect(graded.topics).toContain("nba trade deadline");
    expect(isTransaction(graded)).toBe(true);
  });

  it("cuts Latest, Transfers and Trending from one merged list", () => {
    const merged = [
      headline("Knicks waive Bruce Brown"),
      headline("Celtics rout the Nets", { kind: "recap" }),
      ...Array.from({ length: 40 }, (_, i) => headline(`story ${i}`)),
      headline("Next week's slate", { kind: "preview" }),
    ];
    expect(latestStories(merged)).toHaveLength(LATEST_CAP);
    expect(transferStories(merged).map((story) => story.id)).toEqual(["Knicks waive Bruce Brown"]);
    expect(trendingStories(merged)).toHaveLength(5);
    expect(trendingStories(merged.slice(-1))).toEqual([]);
  });
});
