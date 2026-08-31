import SwiftUI

/// A logo loaded through `LogoCache`: renders instantly when the same mark
/// appears in several sections and retries on reappearance after a failed
/// fetch — the two things `AsyncImage` can't do. A nil URL or failed load
/// leaves the quiet placeholder, never a broken image. Callers size it with
/// `.frame`, matching the old `AsyncImage` call sites.
///
/// In dark mode the ESPN `500-dark` variant is requested instead, falling
/// back to the light mark when a team has none (LogoCache remembers the
/// 404, so the fallback costs one request per team, ever). Conference
/// marks derive no variant and render exactly as before.
struct LogoImage: View {
    let url: URL?
    var placeholder: Color? = Color.bgElevated
    /// `.fill` for imagery that should crop to its frame (player
    /// headshots); logos keep the letterboxing `.fit` default.
    var contentMode: ContentMode = .fit

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?

    private var resolvedURL: URL? {
        colorScheme == .dark ? (url?.darkTeamLogoVariant ?? url) : url
    }

    /// The async-loaded image, or a synchronous cache hit for the first
    /// frame: a freshly-inserted subtree (a tab pane sliding in) otherwise
    /// shows blank discs until its `.task` lands, which read as logos
    /// frozen in place while the cards moved (2026-08-31).
    private var displayImage: UIImage? {
        if let image { return image }
        guard let target = resolvedURL else { return nil }
        if let hit = LogoCache.shared.cachedImage(for: target) { return hit }
        // Dark variant not cached: the light mark is the task's fallback,
        // so it's the sync fallback too.
        if target != url, let url { return LogoCache.shared.cachedImage(for: url) }
        return nil
    }

    var body: some View {
        Group {
            if let image = displayImage {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else if let placeholder {
                Circle().fill(placeholder)
            } else {
                Color.clear
            }
        }
        // task(id:) restarts on every appearance and on appearance-mode
        // flips (resolvedURL changes with the scheme), so a row that failed
        // mid-blip retries when it scrolls back into view and a light logo
        // swaps to its dark twin without relaunching. The previous image
        // stays up while the swap loads — usually an instant cache hit.
        .task(id: resolvedURL) {
            guard let target = resolvedURL else {
                image = nil
                return
            }
            if let loaded = await LogoCache.shared.image(for: target) {
                image = loaded
            } else if target != url, let url,
                      let light = await LogoCache.shared.image(for: url) {
                image = light
            }
        }
    }
}
