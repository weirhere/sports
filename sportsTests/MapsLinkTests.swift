import Foundation
import Testing
@testable import StatSide

/// The venue → Apple Maps search link (COR-151, 2026-11-07).
@Suite struct MapsLinkTests {

    @Test func nameAndCityBecomeOneSearch() {
        let url = MapsLink.url(name: "Benchmark International Arena", city: "Tampa, FL")
        #expect(url?.absoluteString
                == "https://maps.apple.com/?q=Benchmark%20International%20Arena,%20Tampa,%20FL")
    }

    @Test func noCityIsTheNameAlone() {
        #expect(MapsLink.url(name: "Sanford Stadium", city: nil)?.absoluteString
                == "https://maps.apple.com/?q=Sanford%20Stadium")
        #expect(MapsLink.url(name: "Sanford Stadium", city: "  ")?.absoluteString
                == "https://maps.apple.com/?q=Sanford%20Stadium")
    }

    /// The reason this encodes by hand: left to `URLComponents`, the `&`
    /// would end the query and Maps would search for "AT".
    @Test func anAmpersandStaysInTheSearch() throws {
        let url = try #require(MapsLink.url(name: "AT&T Stadium", city: "Arlington, TX"))
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "q" }?.value
        #expect(q == "AT&T Stadium, Arlington, TX")
    }

    @Test func aBlankNameIsNoLink() {
        #expect(MapsLink.url(name: "", city: "Tampa, FL") == nil)
        #expect(MapsLink.url(name: "   ", city: nil) == nil)
    }
}
