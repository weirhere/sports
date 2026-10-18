import Testing
@testable import StatSide

/// The chip that picks the drawn layout says what the sport calls the
/// place — Field, Court or Rink — while the case stays `field` in every
/// league (Andy, 2026-10-18).
struct StartersLayoutTests {
    @Test func theDrawnLayoutIsNamedForTheSportsSurface() {
        #expect(StartersLayout.field.label(for: .collegeFootball) == "Field")
        #expect(StartersLayout.field.label(for: .nfl) == "Field")
        #expect(StartersLayout.field.label(for: .nba) == "Court")
        #expect(StartersLayout.field.label(for: .nhl) == "Rink")
    }

    @Test func theListIsTheListInEveryLeague() {
        for league in League.allCases {
            #expect(StartersLayout.list.label(for: league) == "List")
        }
    }

    @Test func theStoredValueDoesNotChangeWithTheName() {
        #expect(StartersLayout.field.rawValue == "field")
    }
}
