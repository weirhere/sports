import SwiftUI
import Testing
@testable import StatSide

/// TeamPage's light-mode header: when it paints, which ink it picks, and
/// when the logo on it earns a white outline.
struct TeamHeaderPaintTests {
    @Test func darkModeKeepsTheCardHeader() {
        #expect(TeamHeaderPaint(hex: "af5c37", colorScheme: .dark) == nil)
    }

    @Test func noColorKeepsTheCardHeader() {
        #expect(TeamHeaderPaint(hex: nil, colorScheme: .light) == nil)
        #expect(TeamHeaderPaint(hex: "not-hex", colorScheme: .light) == nil)
    }

    @Test func aPaleColorIsNotWorthAHeader() {
        #expect(TeamHeaderPaint(hex: "ffffff", colorScheme: .light) == nil)
    }

    @Test func texasGetsWhiteInk() throws {
        let paint = try #require(TeamHeaderPaint(hex: "af5c37", colorScheme: .light))
        #expect(paint.isDarkGround)
    }

    @Test func aBrightColorGetsBlackInk() throws {
        // Michigan's maize.
        let paint = try #require(TeamHeaderPaint(hex: "ffcb05", colorScheme: .light))
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
}
