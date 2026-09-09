import { describe, it, expect } from "vitest";
import {
  FBS_GROUP_ID,
  FCS_GROUP_ID,
  childrenOf,
  collegeDivision,
  conferenceChain,
  conferenceLogoUrl,
  conferenceName,
  divisionForTeamId,
  isKnownConference,
  leagueWideId,
  orderedCollegeIds,
  orderedIds,
  parentOf,
  tier,
  titleGameIsTopTwo,
  topLevelIds,
} from "./conferences";

describe("conference registry", () => {
  it("knows college football's division groups", () => {
    expect(FBS_GROUP_ID).toBe(80);
    expect(FCS_GROUP_ID).toBe(81);
  });

  it("names known ids and degrades unknowns to Other", () => {
    expect(conferenceName(8, "cfb")).toBe("SEC");
    expect(conferenceName(15, "cfb")).toBe("MAC");
    expect(conferenceName(179, "cfb")).toBe("Ohio Valley");
    expect(conferenceName(999, "cfb")).toBe("Other");
    expect(conferenceName(undefined, "cfb")).toBe("Other");
  });

  it("assigns tiers", () => {
    expect(tier(1, "cfb")).toBe("power4");
    expect(tier(8, "cfb")).toBe("power4");
    expect(tier(18, "cfb")).toBe("independent");
    expect(tier(37, "cfb")).toBe("group5");
    expect(tier(20, "cfb")).toBe("fcs");
    expect(tier(FBS_GROUP_ID, "cfb")).toBe("league");
    expect(tier(999, "cfb")).toBe("other");
  });

  it("orders P4 → G5 → Independents, alphabetical within tiers", () => {
    expect(orderedIds).toEqual([1, 4, 5, 8, 151, 12, 15, 17, 9, 37, 18]);
  });

  it("orders FCS alphabetically — it has one tier", () => {
    const names = orderedCollegeIds("FCS").map((id) => conferenceName(id, "cfb"));
    expect(names).toEqual([...names].sort());
    expect(names).toHaveLength(14);
  });

  it("builds conference logo URLs from the slug map", () => {
    expect(conferenceLogoUrl(8, "cfb")).toBe(
      "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/sec.png"
    );
    expect(conferenceLogoUrl(999, "cfb")).toBeUndefined();
  });

  it("gives United Athletic no mark rather than one that 404s", () => {
    // ESPN publishes no slug for it under any plausible spelling, and FCS
    // does publish marks generally — so the gap is about that conference,
    // not about the league.
    expect(isKnownConference(177, "cfb")).toBe(true);
    expect(conferenceLogoUrl(177, "cfb")).toBeUndefined();
  });

  it("gates the title-game top-two claim per conference era", () => {
    expect(titleGameIsTopTwo(8, 2024, "cfb")).toBe(true);
    expect(titleGameIsTopTwo(8, 2023, "cfb")).toBe(false);
    expect(titleGameIsTopTwo(37, 2025, "cfb")).toBe(false); // Sun Belt divisional
    expect(titleGameIsTopTwo(37, 2026, "cfb")).toBe(true);
    expect(titleGameIsTopTwo(18, 2026, "cfb")).toBe(false); // no title game
    expect(titleGameIsTopTwo(999, 2026, "cfb")).toBe(false);
  });

  it("never claims top-two for FCS or a pro league", () => {
    // FCS settles its title in a 24-team playoff; the pro postseasons are
    // brackets. Neither has a top-two conference championship pairing.
    expect(titleGameIsTopTwo(20, 2026, "cfb")).toBe(false);
    expect(titleGameIsTopTwo(8, 2026, "nfl")).toBe(false);
  });

  it("places college conferences in their division", () => {
    expect(collegeDivision(8, "cfb")).toBe("FBS");
    expect(collegeDivision(20, "cfb")).toBe("FCS");
    expect(collegeDivision(999, "cfb")).toBeUndefined();
    // The pro leagues have no division concept in this sense.
    expect(collegeDivision(8, "nfl")).toBeUndefined();
  });
});

describe("id spaces are per league", () => {
  it("reads group 8 as the SEC or the AFC depending on the league", () => {
    expect(conferenceName(8, "cfb")).toBe("SEC");
    expect(conferenceName(8, "nfl")).toBe("AFC");
  });

  it("reads group 1 as the ACC or the NFC East", () => {
    expect(conferenceName(1, "cfb")).toBe("ACC");
    expect(conferenceName(1, "nfl")).toBe("NFC East");
  });

  it("keeps an unknown id in one league from resolving in another", () => {
    // The NBA has no group 151; college football's American does.
    expect(isKnownConference(151, "cfb")).toBe(true);
    expect(isKnownConference(151, "nba")).toBe(false);
  });
});

describe("pro-league hierarchy", () => {
  it("names a whole-league group", () => {
    expect(leagueWideId("nfl")).toBe(9);
    expect(conferenceName(9, "nfl")).toBe("NFL");
    // College football has no counterpart — group 80 is FBS, a division.
    expect(leagueWideId("cfb")).toBeUndefined();
  });

  it("places a pro team from the hardcoded table", () => {
    // The pro scoreboards ship no group id at all, so without this every
    // pro game falls into "Other".
    expect(divisionForTeamId("2", "nfl")).toBe(4); // Bills → AFC East
    expect(divisionForTeamId("2", "cfb")).toBeUndefined(); // Auburn, from the wire
  });

  it("qualifies a division whose name doesn't place it", () => {
    // The NBA's Atlantic and the NHL's are in different conferences of
    // different sports, so a bare compass point says nothing.
    expect(conferenceName(1, "nba")).toBe("Atlantic (Eastern)");
    expect(conferenceName(32, "nhl")).toBe("Atlantic (Eastern)");
    // "AFC East" already says which half it's in.
    expect(conferenceName(4, "nfl")).toBe("AFC East");
  });

  it("walks a division up to its conference and its league", () => {
    // This is what makes a conference follow match a game: a pro
    // scoreboard gives a team its *division* id, so "I follow the AFC"
    // only means anything if the walk-up happens.
    expect(conferenceChain({ league: "nfl", id: 4 })).toEqual([
      { league: "nfl", id: 4 },
      { league: "nfl", id: 8 },
      { league: "nfl", id: 9 },
    ]);
  });

  it("walks a college conference up to its division root", () => {
    expect(conferenceChain({ league: "cfb", id: 8 })).toEqual([
      { league: "cfb", id: 8 },
      { league: "cfb", id: FBS_GROUP_ID },
    ]);
  });

  it("lists a conference's divisions and a league's conferences", () => {
    expect(parentOf(4, "nfl")).toBe(8);
    expect(childrenOf(8, "nfl")).toEqual([4, 12, 13, 6]);
    expect(topLevelIds("nfl")).toEqual([8, 7]);
    // College football nests nothing.
    expect(childrenOf(8, "cfb")).toEqual([]);
  });

  it("gives a division its conference's mark", () => {
    // An AFC East header showing the AFC shield reads better than a bare
    // glyph — divisions publish no mark of their own.
    expect(conferenceLogoUrl(4, "nfl")).toBe(conferenceLogoUrl(8, "nfl"));
    expect(conferenceLogoUrl(8, "nfl")).toBe(
      "https://a.espncdn.com/i/teamlogos/nfl/500/afc.png"
    );
  });

  it("gives an NBA division its conference's own mark", () => {
    // Filed beside the team logos, not in an `nba_conf` bucket — which is
    // where an earlier probe looked, found nothing, and wrongly concluded
    // they didn't exist.
    expect(conferenceLogoUrl(5, "nba")).toBe(
      "https://a.espncdn.com/i/teamlogos/nba/500/east.png"
    );
    expect(conferenceLogoUrl(1, "nba")).toBe(conferenceLogoUrl(5, "nba"));
  });

  it("falls a league with no conference marks back to its own shield", () => {
    // The NHL publishes none anywhere, so its conferences would otherwise
    // show nothing at all.
    expect(conferenceLogoUrl(7, "nhl")).toBe(
      "https://a.espncdn.com/i/teamlogos/leagues/500/nhl.png"
    );
  });
});
