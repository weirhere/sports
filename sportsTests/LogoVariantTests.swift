import Foundation
import Testing
@testable import StatSide

/// The dark-variant URL is derived, never decoded — the scoreboard payload
/// carries only the light logo. These pin the derivation's shape and, more
/// importantly, everything it must refuse to touch.
@Suite struct LogoVariantTests {
    @Test func derivesDarkVariantForTeamLogo() {
        let url = URL(string: "https://a.espncdn.com/i/teamlogos/ncaa/500/194.png")!
        #expect(url.darkTeamLogoVariant?.absoluteString
            == "https://a.espncdn.com/i/teamlogos/ncaa/500-dark/194.png")
    }

    @Test func preservesQueryString() {
        let url = URL(string: "https://a.espncdn.com/i/teamlogos/ncaa/500/61.png?w=80&h=80")!
        #expect(url.darkTeamLogoVariant?.absoluteString
            == "https://a.espncdn.com/i/teamlogos/ncaa/500-dark/61.png?w=80&h=80")
    }

    /// CFBD's logo lists point at the same CDN over http; the client
    /// upgrades to https before the URL reaches derivation.
    @Test func derivesForCFBDStyleURL() {
        let url = URL(string: "https://a.espncdn.com/i/teamlogos/ncaa/500/2132.png")!
        #expect(url.darkTeamLogoVariant != nil)
    }

    @Test func conferenceMarksDoNotDerive() {
        let url = URL(string: "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/big_ten.png")!
        #expect(url.darkTeamLogoVariant == nil)
    }

    @Test func guidLogoURLsDoNotDerive() {
        let url = URL(string: "https://a.espncdn.com/guid/0aa5ebde-6a2d-e75e-72d1-fdcb0b32c528/logos/default.png")!
        #expect(url.darkTeamLogoVariant == nil)
    }

    @Test func nonESPNHostsDoNotDerive() {
        let url = URL(string: "https://example.com/i/teamlogos/ncaa/500/194.png")!
        #expect(url.darkTeamLogoVariant == nil)
    }
}
