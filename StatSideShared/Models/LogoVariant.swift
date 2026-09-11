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

    /// The same headshot, asked for at row size.
    ///
    /// ESPN's roster payload links `/i/headshots/…/full/{id}.png`, which is a
    /// 600×436 PNG weighing ~200 KB. A college football roster is 100 players,
    /// so a Roster tab rendered off those URLs pulls ~20 MB to fill a screenful
    /// of 36pt discs. The CDN's own resizer takes the file down to ~18 KB —
    /// `combiner/i?img={path}&w=150&h=110`, which is ≥110px on the short side
    /// and so still sharp in a 36pt disc at 3×.
    ///
    /// Verified live 2026-09-10 on all four leagues; a missing player 404s
    /// cleanly, which `LogoCache` already remembers rather than re-requesting.
    /// The `?w=` parameters the path form accepts are ignored — the full image
    /// comes back at full size — so the combiner is the only way to ask.
    var headshotThumbnail: URL? {
        guard let host = host(), host.hasSuffix("espncdn.com"),
              path().contains("/i/headshots/") else { return nil }
        return URL(string:
            "https://a.espncdn.com/combiner/i?img=\(path())&w=150&h=110")
    }
}
