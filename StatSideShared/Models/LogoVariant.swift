import Foundation

/// ESPN publishes dark-mode team marks alongside the defaults
/// (`/i/teamlogos/ncaa/500-dark/` next to `/i/teamlogos/ncaa/500/`, and the
/// same pair under `nfl/` — verified live 2026-09-05), but the scoreboard
/// payload carries only the light URL, so the dark one is derived, never
/// decoded. Conference marks and GUID-based logo URLs have no verified dark
/// twin and deliberately don't match; callers treat nil as "use the light
/// logo".
nonisolated extension URL {
    var darkTeamLogoVariant: URL? {
        guard let host = host(), host.hasSuffix("espncdn.com") else { return nil }
        let path = path()
        for component in League.allCases.map(\.teamLogoPathComponent) {
            let light = "/i/teamlogos/\(component)/500/"
            guard path.contains(light) else { continue }
            return URL(string: absoluteString.replacingOccurrences(
                of: light, with: "/i/teamlogos/\(component)/500-dark/"))
        }
        return nil
    }
}
