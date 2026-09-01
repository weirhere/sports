import UIKit

/// In-memory logo store. SwiftUI's `AsyncImage` fetches a URL exactly once
/// and never retries, so a network blip at cold launch permanently blanks
/// whichever rows rendered first (the Following section, top of the scores
/// screen). This actor dedupes in-flight fetches, remembers successes, and
/// forgets transient failures so a view can retry on its next appearance.
///
/// A 4xx is not transient: it means the asset doesn't exist — which the
/// dark-variant fallback hits for teams with no `500-dark` mark — and
/// retrying it on every row appearance would hammer ESPN with 404s. Those
/// URLs are remembered as missing and answered nil without a request.
///
/// UIKit exception: decoding raw bytes into an image needs `UIImage` —
/// SwiftUI's `Image` can't be built from `Data`.
actor LogoCache {
    static let shared = LogoCache()

    private enum FetchOutcome {
        case image(UIImage)
        case missing
        case transient
    }

    /// The success store, and the one part of the cache readable without
    /// the actor hop: an await lands a frame late, which froze logos as
    /// blank discs while a freshly-inserted tab pane slid in (2026-08-31).
    /// NSCache does its own locking, so the unsafe opt-out is sound; its
    /// memory-pressure eviction just means a rare re-fetch.
    ///
    /// Capped at ~64 MB of decoded pixels: uncapped, a session that browsed
    /// six weeks of slates held 370+ MB of 500px logo bitmaps (2026-09-01
    /// perf pass) — NSCache would shed them under pressure, but an explicit
    /// budget keeps the footprint honest instead of riding jetsam's
    /// judgment. Eviction cost = decoded bytes, set per insert below.
    nonisolated(unsafe) private let loaded: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()
    private var missing: Set<URL> = []
    private var inFlight: [URL: Task<FetchOutcome, Never>] = [:]

    /// A cache hit on the calling thread — for first-frame paints. Misses
    /// (including still-loading marks) come back nil; callers follow up
    /// with `image(for:)`.
    nonisolated func cachedImage(for url: URL) -> UIImage? {
        loaded.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let image = loaded.object(forKey: url as NSURL) { return image }
        if missing.contains(url) { return nil }
        let task = inFlight[url] ?? Task<FetchOutcome, Never> {
            guard let (data, response) = try? await URLSession.shared.data(from: url)
            else { return .transient }
            if let http = response as? HTTPURLResponse,
               (400 ..< 500).contains(http.statusCode) { return .missing }
            guard (response as? HTTPURLResponse).map({ (200 ..< 300).contains($0.statusCode) }) ?? true,
                  let image = UIImage(data: data)
            else { return .transient }
            return .image(image)
        }
        inFlight[url] = task
        let outcome = await task.value
        inFlight[url] = nil
        switch outcome {
        case .image(let image):
            let pixels = image.size.width * image.scale * image.size.height * image.scale
            loaded.setObject(image, forKey: url as NSURL, cost: Int(pixels) * 4)
            return image
        case .missing:
            missing.insert(url)
            return nil
        case .transient:
            return nil
        }
    }
}
