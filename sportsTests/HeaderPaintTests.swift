import SwiftUI
import Testing
@testable import StatSide

/// TeamPage's light-mode header: when it paints, which ink it picks, and
/// when the logo on it earns a white outline.
struct HeaderPaintTests {
    @Test func darkModeKeepsTheCardHeader() {
        #expect(HeaderPaint(hex: "af5c37", colorScheme: .dark) == nil)
    }

    @Test func noColorKeepsTheCardHeader() {
        #expect(HeaderPaint(hex: nil, colorScheme: .light) == nil)
        #expect(HeaderPaint(hex: "not-hex", colorScheme: .light) == nil)
    }

    @Test func aPaleColorIsNotWorthAHeader() {
        #expect(HeaderPaint(hex: "ffffff", colorScheme: .light) == nil)
    }

    @Test func texasGetsWhiteInk() throws {
        let paint = try #require(HeaderPaint(hex: "af5c37", colorScheme: .light))
        #expect(paint.isDarkGround)
    }

    @Test func aBrightColorGetsBlackInk() throws {
        // Michigan's maize.
        let paint = try #require(HeaderPaint(hex: "ffcb05", colorScheme: .light))
        #expect(!paint.isDarkGround)
    }

    @Test func aMarkInTheGroundColorConflicts() {
        let orange = (r: 0.686, g: 0.361, b: 0.216)
        #expect(LogoContrast.conflicts(pixels: Array(repeating: orange, count: 100), ground: orange))
    }

    @Test func aWhiteMarkOnNavyDoesNot() {
        let navy = (r: 0.0, g: 0.153, b: 0.298)
        let white = (r: 1.0, g: 1.0, b: 1.0)
        #expect(!LogoContrast.conflicts(pixels: Array(repeating: white, count: 100), ground: navy))
    }

    @Test func aSmallPatchInTheGroundColorStillCounts() {
        // "If the logo conflicts with that color at all" — 5% of the mark.
        let navy = (r: 0.0, g: 0.153, b: 0.298)
        let white = (r: 1.0, g: 1.0, b: 1.0)
        let pixels = Array(repeating: white, count: 95) + Array(repeating: navy, count: 5)
        #expect(LogoContrast.conflicts(pixels: pixels, ground: navy))
    }

    @Test func aStrayPixelDoesNot() {
        let navy = (r: 0.0, g: 0.153, b: 0.298)
        let white = (r: 1.0, g: 1.0, b: 1.0)
        let pixels = Array(repeating: white, count: 199) + [navy]
        #expect(!LogoContrast.conflicts(pixels: pixels, ground: navy))
    }

    @Test func aMarkIsTheColorItIsMostlyMadeOf() {
        let navy = (r: 0.094, g: 0.176, b: 0.408)
        let gold = (r: 0.8, g: 0.6, b: 0.1)
        let pixels = Array(repeating: navy, count: 60) + Array(repeating: gold, count: 30)
        #expect(LogoContrast.dominantHex(pixels: pixels) == "182d68")
    }

    @Test func colorBeatsBlackType() {
        // Black lettering outnumbers the red, but the red is the brand.
        let black = (r: 0.0, g: 0.0, b: 0.0)
        let red = (r: 0.8, g: 0.1, b: 0.1)
        let pixels = Array(repeating: black, count: 70) + Array(repeating: red, count: 30)
        #expect(LogoContrast.dominantHex(pixels: pixels) == "cc1a1a")
    }

    @Test func anAllWhiteMarkHasNoColor() {
        let white = (r: 1.0, g: 1.0, b: 1.0)
        #expect(LogoContrast.dominantHex(pixels: Array(repeating: white, count: 50)) == nil)
    }

    @Test func onlyTheProLeaguesCarryABrandColor() {
        #expect(League.nfl.brandColorHex == "013369")
        #expect(League.collegeFootball.brandColorHex == nil)
    }

    /// A team page paints its first frame from the shipped table (2026-10-03)
    /// rather than opening white until the schedule lands.
    @Test func everyLeaguesTeamsShipWithTheirColor() {
        #expect(HeaderPaint.bundled["nfl:5"] != nil)      // Browns
        #expect(HeaderPaint.bundled["cfb:239"] != nil)    // Baylor
        #expect(HeaderPaint.bundled["nba:13"] != nil)     // Lakers
        #expect(HeaderPaint.bundled["nhl:1"] != nil)      // Bruins
        #expect(HeaderPaint.knownHex(forKey: "nfl:5") == HeaderPaint.bundled["nfl:5"])
    }
}
