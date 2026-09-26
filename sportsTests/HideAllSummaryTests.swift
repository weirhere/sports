import Testing
@testable import StatSide

struct HideAllSummaryTests {
    private func sections(_ titles: String...) -> [GameSection] {
        titles.map { GameSection(id: "conf-\($0)", title: $0, games: []) }
    }

    @Test func namesTwoAndCountsTheRest() {
        #expect(HideAllControl.summary(of: sections("Big Ten", "SEC", "ACC", "Big 12"))
                == "Big Ten, SEC and 2 other leagues or conferences play today")
    }

    @Test func singularRemainder() {
        #expect(HideAllControl.summary(of: sections("Big Ten", "SEC", "ACC"))
                == "Big Ten, SEC and 1 other league or conference play today")
    }

    @Test func twoSections() {
        #expect(HideAllControl.summary(of: sections("NFL", "NHL")) == "NFL and NHL play today")
    }

    @Test func oneSection() {
        #expect(HideAllControl.summary(of: sections("NBA")) == "NBA plays today")
    }

    @Test func catchAllIsCountedNotNamed() {
        let slate = sections("Big Ten")
            + [GameSection(id: GameSection.otherPrefix + "cfb", title: "Other", games: [])]
        #expect(HideAllControl.summary(of: slate)
                == "Big Ten and 1 other league or conference play today")
    }
}
