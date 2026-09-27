// The web twin of iOS `NewsTests` (sportsTests/NewsTests.swift), over the
// same payloads: the NBA summary's recap, a Knicks `/news?team=18` feed and
// one content-API story, fetched 2026-09-27.

import { describe, it, expect } from "vitest";
import summaryJson from "./espn/__fixtures__/nba-summary-article.json";
import feedJson from "./espn/__fixtures__/nba-team-news.json";
import storyJson from "./espn/__fixtures__/nba-news-story.json";
import {
  forYou,
  isFlooded,
  leagueFeed,
  toppedUp,
  newsStory,
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
  storyForGame,
  storyKind,
  type NewsStory,
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
