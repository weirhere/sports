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

    private var loaded: [URL: UIImage] = [:]
    private var missing: Set<URL> = []
    private var inFlight: [URL: Task<FetchOutcome, Never>] = [:]

    func image(for url: URL) async -> UIImage? {
        if let image = loaded[url] { return image }
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
            loaded[url] = image
            return image
        case .missing:
            missing.insert(url)
            return nil
        case .transient:
            return nil
        }
    }
}
