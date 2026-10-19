import Foundation
import Testing
@testable import StatSide

// docs/news.md: the game page's story card, the team page's News tab and
// the reader. Fixtures are real payloads — the summaries the app already
// had, a Knicks `/news?team=18` feed and one content-API story, both
// fetched 2026-09-27 and trimmed of the photos and embeds nothing decodes.

private final class NewsFixtureToken {}

private func fixtureData(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: NewsFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private func summary(_ name: String, league: League) throws -> GameSummary {
    let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixtureData(name))
    return ESPNMapper.gameSummary(from: dto, league: league)
}

@Suite struct NewsTests {
    // MARK: - The summary's own story (N2, N3)

    @Test func readsTheRecapOutOfTheSummary() throws {
        let story = try #require(try summary("nba-summary", league: .nba).article)
        #expect(story.kind == .recap)
        #expect(story.gameId == "401810871")
        #expect(story.attribution == "AP")
        #expect(story.teams.map(\.id) == ["17", "18"])
        #expect(story.dek?.hasPrefix("Karl-Anthony Towns") == true)
        #expect(story.published != nil)
        // Whole, so opening it costs nothing.
        #expect(story.bodyURL == nil)
        #expect((story.body?.count ?? 0) > 5)
    }

    @Test func tidiesTheDatelineAndEndsAtTheWireRule() throws {
        let body = try #require(try summary("nba-summary", league: .nba).article?.body)
        guard case .paragraph(let first)? = body.first else {
            Issue.record("expected a paragraph first"); return
        }
        #expect(first.hasPrefix("NEW YORK — Karl-Anthony Towns had 26"))
        #expect(body.contains(.heading("Up next")))
        // AP's hub link sits after its "------" rule, and the story is over
        // at the rule.
        #expect(body.last == .paragraph("Nets: Visit the Sacramento Kings on Sunday."))
        #expect(!body.contains { block in
            guard case .paragraph(let text) = block else { return false }
            return text.contains("<") || text.contains("apnews.com")
        })
    }

    @Test func gamePageShowsTheRecapOnlyOnceFinal() throws {
        let final = try summary("nba-summary", league: .nba)
        let id = "401810871"
        #expect(final.story(forGame: id, status: .final(detail: nil))?.kind == .recap)
        #expect(final.story(forGame: id, status: .pre(detail: nil)) == nil)
        #expect(final.story(forGame: id, status: .live(displayClock: nil, period: nil, detail: nil,
                                                       phase: .playing, possessionTeamId: nil)) == nil)
        // A story filed under another game never shows.
        #expect(final.story(forGame: "1", status: .final(detail: nil)) == nil)
    }

    @Test func everyLeaguesRecapMaps() throws {
        for (name, league) in [("summary-final-live", League.collegeFootball),
                               ("nba-summary", .nba), ("nhl-summary", .nhl)] {
            let story = try #require(try summary(name, league: league).article, "\(name)")
            #expect(story.kind == .recap, "\(name)")
            #expect(story.teams.count == 2, "\(name)")
        }
    }

    // MARK: - The team feed (N9, N10)

    @Test func keepsOnlyStoriesAboutTheTeam() throws {
        let dto = try JSONDecoder().decode(NewsFeedDTO.self, from: fixtureData("nba-team-news"))
        let stories = NewsMapper.teamFeed(from: dto, teamId: "18", league: .nba)
        // 25 in the feed, all tagged with the Knicks; 8 about them.
        #expect(dto.articles?.elements.count == 25)
        #expect(stories.count == 8)
        #expect(stories.allSatisfy { $0.isFocused(on: "18") })
        // Headlines only: each opens onto one request.
        #expect(stories.allSatisfy { $0.body == nil && $0.bodyURL != nil })
        #expect(zip(stories, stories.dropFirst()).allSatisfy {
            ($0.published ?? .distantPast) >= ($1.published ?? .distantPast)
        })
    }

    @Test func dropsVideoAndTickets() {
        #expect(NewsStory.Kind(espnType: "Media") == nil)
        #expect(NewsStory.Kind(espnType: "Eticket") == nil)
        #expect(NewsStory.Kind(espnType: nil) == nil)
        #expect(NewsStory.Kind(espnType: "HeadlineNews") == .headline)
        #expect(NewsStory.Kind(espnType: "Preview") == .preview)
    }

    @Test func aRoundupIsNotTheTeamsStory() {
        func story(_ ids: [String]) -> NewsStory {
            NewsStory(id: "1", kind: .story, league: .nba, headline: "h", dek: nil,
                      attribution: nil, published: nil, gameId: nil,
                      teams: ids.map { .init(id: $0, name: $0) })
        }
        #expect(story(["18"]).isFocused(on: "18"))
        #expect(story(["18", "17"]).isFocused(on: "18"))
        #expect(!story(["18", "17", "2"]).isFocused(on: "18"))
        #expect(!story(["17"]).isFocused(on: "18"))
    }

    // MARK: - The News tab (E26)

    @Test func aLeagueFeedPutsPreviewsLast() throws {
        // ESPN's college-football feed on 2026-09-27 was 50 AP previews
        // published within four minutes. Newer isn't enough to lead.
        let json = """
        {"articles": [
          {"id": 1, "type": "Preview", "headline": "Next week", "published": "2026-09-27T19:47:00Z",
           "links": {"api": {"self": {"href": "https://content.core.api.espn.com/v1/sports/news/1"}}}},
          {"id": 2, "type": "Story", "headline": "Older story", "published": "2026-09-27T12:00:00Z",
           "links": {"api": {"self": {"href": "https://content.core.api.espn.com/v1/sports/news/2"}}}},
          {"id": 3, "type": "Media", "headline": "A video", "published": "2026-09-27T20:00:00Z",
           "links": {"api": {"self": {"href": "https://content.core.api.espn.com/v1/sports/news/3"}}}},
          {"id": 4, "type": "HeadlineNews", "headline": "Newest news", "published": "2026-09-27T18:00:00Z",
           "links": {"api": {"self": {"href": "https://content.core.api.espn.com/v1/sports/news/4"}}}}
        ]}
        """
        let dto = try JSONDecoder().decode(NewsFeedDTO.self, from: Data(json.utf8))
        let stories = NewsMapper.leagueFeed(from: dto, league: .collegeFootball)
        #expect(stories.map(\.id) == ["4", "2", "1"])
    }

    @Test func forYouMergesEachStoryOnceNewestFirst() {
        func story(_ id: String, _ published: String) -> NewsStory {
            NewsStory(id: id, kind: .recap, league: .nba, headline: id, dek: nil,
                      attribution: nil, published: ISO8601DateFormatter().date(from: published),
                      gameId: nil, teams: [])
        }
        // A recap tags both teams, and both are followed.
        let knicks = [story("recap", "2026-09-27T03:00:00Z"), story("knicks", "2026-09-26T12:00:00Z")]
        let nets = [story("nets", "2026-09-27T12:00:00Z"), story("recap", "2026-09-27T03:00:00Z")]
        #expect(NewsMapper.forYou([knicks, nets]).map(\.id) == ["nets", "recap", "knicks"])
    }

    @Test func aPreviewFloodIsToppedUpWithTheRankedTeams() {
        func story(_ id: String, _ kind: NewsStory.Kind, _ published: String) -> NewsStory {
            NewsStory(id: id, kind: kind, league: .collegeFootball, headline: id, dek: nil,
                      attribution: nil, published: ISO8601DateFormatter().date(from: published),
                      gameId: nil, teams: [])
        }
        // The 2026-09-27 feed: nothing but next week's previews.
        let flood = (1...12).map { story("p\($0)", .preview, "2026-09-27T19:4\($0 % 10):00Z") }
        #expect(NewsMapper.isFlooded(flood))
        #expect(!NewsMapper.isFlooded((1...10).map { story("s\($0)", .story, "2026-09-27T12:00:00Z") }))

        // Two ranked teams' feeds, one recap shared between them.
        let michigan = [story("recap", .recap, "2026-09-27T03:00:00Z"),
                        story("mich", .headline, "2026-09-26T12:00:00Z")]
        let iowa = [story("recap", .recap, "2026-09-27T03:00:00Z"),
                    story("iowa-preview", .preview, "2026-09-27T20:00:00Z")]
        let page = NewsMapper.toppedUp(Array(flood.prefix(2)), with: [michigan, iowa])
        #expect(page.map(\.id) == ["recap", "mich", "iowa-preview", "p2", "p1"])
    }

    @Test func aPlayersFeedIsTheOverviewsOwnList() throws {
        let dto = try JSONDecoder().decode(AthleteOverviewNewsDTO.self,
                                           from: fixtureData("nba-athlete-overview"))
        let stories = NewsMapper.playerFeed(from: dto, league: .nba)
        // Brunson's 13, less the video.
        #expect(dto.news?.elements.count == 13)
        #expect(!stories.isEmpty && stories.count < 13)
        #expect(stories.allSatisfy { $0.bodyURL != nil })
        #expect(zip(stories, stories.dropFirst()).allSatisfy {
            ($0.published ?? .distantPast) >= ($1.published ?? .distantPast)
        })
    }

    // MARK: - The reader (N4)

    @Test func readsTheContentAPIsParagraphs() throws {
        let dto = try JSONDecoder().decode(NewsHeadlinesDTO.self, from: fixtureData("nba-news-story"))
        let article = try #require(dto.headlines?.elements.first)
        let blocks = StoryText.blocks(fromHTML: article.story ?? "")
        #expect(blocks.count == 5)
        #expect(blocks.first == .paragraph(
            "New York Knicks star guard Jalen Brunson is ready for the 2026-27 season after acknowledging that he underwent left wrist surgery."))
        #expect(NewsMapper.attribution(byline: article.byline, source: article.source) == "ESPN")
    }

    @Test func stripsTagsAndDecodesEntities() {
        let html = "<p>A &amp; B&#8217;s &bogus; &#x2014;</p><p> </p>"
            + "<h2>Head <a href=\"x\">line</a></h2><p>C<img src='a'/></p>"
        #expect(StoryText.blocks(fromHTML: html) == [
            .paragraph("A & B’s &bogus; —"), .heading("Head line"), .paragraph("C"),
        ])
    }

    @Test func attributionPrefersTheByline() {
        #expect(NewsMapper.attribution(byline: "Zach Kram", source: "ESPN") == "Zach Kram")
        #expect(NewsMapper.attribution(byline: nil, source: "Associated Press") == "AP")
        #expect(NewsMapper.attribution(byline: " ", source: nil) == nil)
    }

    // MARK: - Timestamps (N7)

    @Test func listTimesAreRelative() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let iso = ISO8601DateFormatter()
        let now = try #require(iso.date(from: "2026-09-27T20:00:00Z"))   // 4 PM Eastern
        func relative(_ string: String) throws -> String {
            NewsTimestamp.relative(try #require(iso.date(from: string)), now: now,
                                   calendar: calendar, locale: Locale(identifier: "en_US"))
        }
        #expect(try relative("2026-09-27T19:59:30Z") == "Just now")
        #expect(try relative("2026-09-27T19:48:00Z") == "12m ago")
        #expect(try relative("2026-09-27T13:00:00Z") == "7h ago")
        // 11 PM Eastern the night before is yesterday, whatever UTC says.
        #expect(try relative("2026-09-27T03:00:00Z") == "Yesterday")
        #expect(try relative("2026-09-24T12:00:00Z") == "Sep 24")
        #expect(try relative("2025-11-05T12:00:00Z") == "Nov 5, 2025")
    }

    // MARK: - Search's News scope (E26)

    @Test func searchReadsTheArticleGroup() throws {
        let dto = try JSONDecoder().decode(SearchResponseDTO.self, from: fixtureData("search-knicks"))
        let stories = AthleteSearchClient.stories(in: dto)
        // "knicks" on 2026-09-27: ten articles, one a New York story filed
        // under the NFL. Clips and replays are video and never map.
        #expect(stories.count == 10)
        #expect(stories.first?.id == "50039929")
        #expect(stories.first?.kind == .headline)
        #expect(stories.first?.league == .nba)
        #expect(stories.first?.attribution == "AP")
        #expect(stories.first?.published != nil)
        #expect(stories.first?.bodyURL?.absoluteString
                == "https://content.core.api.espn.com/v1/sports/news/50039929")
        #expect(stories.contains { $0.league == .nfl })
        #expect(AthleteSearchClient.athletes(in: dto).isEmpty)
    }

    @Test func searchDropsLeaguesTheAppDoesNotCover() {
        #expect(NewsMapper.league(fromStoryLink: "https://www.espn.com/college-football/story/_/id/1/x") == .collegeFootball)
        #expect(NewsMapper.league(fromStoryLink: "https://www.espn.com/soccer/story/_/id/1/x") == nil)
        #expect(NewsMapper.league(fromStoryLink: nil) == nil)
        // AP's recaps and previews use ESPN's older paths.
        let recap = "http://www.espn.com/ncf/recap?gameId=401858463"
        #expect(NewsMapper.league(fromStoryLink: recap) == .collegeFootball)
        #expect(NewsMapper.gameId(fromStoryLink: recap) == "401858463")
        #expect(NewsStory.Kind(espnType: "headlinenews") == .headline)
        #expect(NewsStory.Kind(espnType: "media") == nil)
    }

    // MARK: - Photos (2026-09-27)

    @Test func aStoryLeadsWithItsHeaderPhoto() {
        let video = NewsImageDTO(type: "Media", url: "https://example.com/still.jpg")
        let header = NewsImageDTO(type: "header", url: "https://example.com/header.jpg")
        let plain = NewsImageDTO(type: nil, url: "https://example.com/plain.jpg")
        #expect(NewsMapper.imageURL(from: [video, plain, header])?.lastPathComponent == "header.jpg")
        // No header: a photo before a video's still.
        #expect(NewsMapper.imageURL(from: [video, plain])?.lastPathComponent == "plain.jpg")
        // Only a still: better than nothing.
        #expect(NewsMapper.imageURL(from: [video])?.lastPathComponent == "still.jpg")
        #expect(NewsMapper.imageURL(from: [NewsImageDTO(type: "header", url: nil)]) == nil)
        #expect(NewsMapper.imageURL(from: []) == nil)
        // ESPN's generated matchup cards 404; a recap with only one has none.
        let stitcher = NewsImageDTO(type: "header",
                                    url: "https://s.espncdn.com/stitcher/sports/football/college-football/events/401858463.png?templateId=espn")
        #expect(NewsMapper.imageURL(from: [stitcher]) == nil)
        #expect(NewsMapper.imageURL(from: [stitcher, plain])?.lastPathComponent == "plain.jpg")
    }

    @Test func aSectionLeadsWithAPhoto() {
        func story(_ id: String, photo: Bool = false) -> NewsStory {
            NewsStory(id: id, kind: .story, league: .nba, headline: id, dek: nil,
                      attribution: nil, published: nil, gameId: nil, teams: [],
                      imageURL: photo ? URL(string: "https://example.com/\(id).jpg") : nil)
        }
        let list = [story("a"), story("b"), story("c", photo: true), story("d"), story("e"), story("f")]
        #expect(StorySection<Never>.arranged(list).map(\.id) == ["c", "a", "b", "d", "e"])
        #expect(StorySection<Never>.arranged([story("a"), story("b")]).map(\.id) == ["a", "b"])
    }

    // MARK: - Transfers and the For you sheet (2026-10-19)

    private func headline(_ text: String, kind: NewsStory.Kind = .headline, dek: String? = nil,
                          topics: [String] = []) -> NewsStory {
        NewsStory(id: text, kind: kind, league: .nba, headline: text, dek: dek,
                  attribution: nil, published: nil, gameId: nil, teams: [], topics: topics)
    }

    @Test func transactionsAreTradesSigningsAndWaivers() {
        // The 2026-10-19 probe's headlines, none of which ESPN tagged.
        #expect(headline("Knicks waive Bruce Brown, keep James Wiseman ahead of opener").isTransaction)
        #expect(headline("Still awaiting trade, Connor Hellebuyck could rejoin Jets when suspension ends").isTransaction)
        #expect(headline("Jerry Jeudy, amid trade buzz, has clutch catch in Browns' win").isTransaction)
        #expect(headline("Bears agree to terms with veteran kicker").isTransaction)
        #expect(headline("Four-star QB commits to Ohio State").isTransaction)
        #expect(headline("Star receiver enters the transfer portal").isTransaction)
        #expect(headline("Towns, Knicks finalize four-year extension").isTransaction)
        // The dek counts too.
        #expect(headline("Roster moves", dek: "The Jets released their starting kicker").isTransaction)
        // Whole words: "design" and "signal" are not "sign".
        #expect(!headline("Designs on a title: inside the Thunder's offseason").isTransaction)
        #expect(!headline("A signal win for the Celtics' bench").isTransaction)
        // "deal" is every game story's word.
        #expect(!headline("Judging overreactions to NFL Week 6: Regretting Daniel Jones, A.J. Brown deals?").isTransaction)
        #expect(!headline("The stat that could swing every NBA team's 2026-27 season").isTransaction)
    }

    @Test func gameStoriesAreNeverTransactions() {
        #expect(!headline("Jets trade blows with Bills in overtime thriller", kind: .recap).isTransaction)
        #expect(!headline("Preview: Lakers sign off on new-look rotation", kind: .preview).isTransaction)
    }

    @Test func onlyUnambiguousTopicsMarkATransaction() throws {
        #expect(headline("Deadline day", topics: ["nba trade deadline"]).isTransaction)
        #expect(headline("Portal watch", topics: ["transfer portal"]).isTransaction)
        // ESPN hangs "nba free agency" on a stat column; the tag alone
        // doesn't make one.
        #expect(!headline("The stat that could swing every NBA team's season",
                          topics: ["daily", "nba free agency"]).isTransaction)
        // The fixture's topics come through the mapper, lowercased.
        let dto = try JSONDecoder().decode(NewsFeedDTO.self, from: fixtureData("nba-team-news"))
        let stories = (dto.articles?.elements ?? []).compactMap { NewsMapper.story(from: $0, league: .nba) }
        let graded = try #require(stories.first { $0.id == "48957095" })
        #expect(graded.topics.contains("nba free agency"))
        #expect(graded.topics.contains("nba trade deadline"))
        #expect(graded.isTransaction)
    }

    @Test func theNewsTabsRunForYouLatestTransfersLeagues() {
        #expect(NewsFeedStore.Feed.allCases.map(\.title) == ["For you", "Latest", "Transfers", "Leagues"])
        // The Leagues page lists leagues as the Leagues tab does.
        #expect(League.displayOrder == [.nba, .collegeFootball, .nfl, .nhl])
    }

    @MainActor
    @Test func theForYouSheetHidesATeamAndRemembersIt() throws {
        let name = "NewsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let ui = UIStateStore(defaults: defaults)
        #expect(ui.isShownInNews("nba:18"))
        ui.setShownInNews(false, for: "nba:18")
        #expect(!ui.isShownInNews("nba:18"))
        #expect(ui.isShownInNews("nba:2"))
        // The follows For you is built from drop the hidden team.
        let keys: Set<String> = ["nba:18", "nba:2", "nfl:26"]
        // Sorted: a Set's order is the hash's, and CI's differed from the
        // Mac's the first time this ran.
        #expect(keys.filter { ui.isShownInNews($0) }.sorted() == ["nba:2", "nfl:26"])
        // And a relaunch reads it back.
        #expect(!UIStateStore(defaults: defaults).isShownInNews("nba:18"))
        ui.setShownInNews(true, for: "nba:18")
        #expect(UIStateStore(defaults: defaults).isShownInNews("nba:18"))
    }
}
