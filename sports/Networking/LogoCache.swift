import UIKit

/// In-memory logo store. SwiftUI's `AsyncImage` fetches a URL exactly once
/// and never retries, so a network blip at cold launch permanently blanks
/// whichever rows rendered first (the Following section, top of the scores
/// screen). This actor dedupes in-flight fetches, remembers successes, and
/// forgets failures so a view can retry on its next appearance.
///
/// UIKit exception: decoding raw bytes into an image needs `UIImage` —
/// SwiftUI's `Image` can't be built from `Data`.
actor LogoCache {
    static let shared = LogoCache()

    private var loaded: [URL: UIImage] = [:]
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    func image(for url: URL) async -> UIImage? {
        if let image = loaded[url] { return image }
        if let task = inFlight[url] { return await task.value }
        let task = Task<UIImage?, Never> {
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse).map({ (200 ..< 300).contains($0.statusCode) }) ?? true,
                  let image = UIImage(data: data)
            else { return nil }
            return image
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image { loaded[url] = image }
        return image
    }
}
