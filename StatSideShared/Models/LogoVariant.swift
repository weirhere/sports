import Foundation

/// ESPN publishes dark-mode team marks alongside the defaults
/// (`/i/teamlogos/ncaa/500-dark/` next to `/i/teamlogos/ncaa/500/`), but the
/// scoreboard payload carries only the light URL — so the dark one is
/// derived, never decoded. Conference marks (`ncaa_conf`) and GUID-based
/// logo URLs have no verified dark twin and deliberately don't match;
/// callers treat nil as "use the light logo".
nonisolated extension URL {
    var darkTeamLogoVariant: URL? {
        guard let host = host(), host.hasSuffix("espncdn.com"),
              path().contains("/i/teamlogos/ncaa/500/") else { return nil }
        return URL(string: absoluteString.replacingOccurrences(
            of: "/i/teamlogos/ncaa/500/", with: "/i/teamlogos/ncaa/500-dark/"))
    }
}
