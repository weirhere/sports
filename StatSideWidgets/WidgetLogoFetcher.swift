import CryptoKit
import Foundation
import UIKit

/// Widget views render once — no `.task`, no AsyncImage — so logos are
/// fetched in the timeline provider and byte-cached in the App Group
/// container. Steady-state reloads do zero image networking.
nonisolated enum WidgetLogoFetcher {
    /// 2x a 40 pt render slot; logos are small marks, not hero art.
    private static let maxPixelSize: CGFloat = 80

    static func logo(for url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if let cached = cachedLogo(for: url) { return cached }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let image = UIImage(data: data) else { return nil }
        let size = thumbnailSize(for: image.size)
        let thumbnail = await image.byPreparingThumbnail(ofSize: size) ?? image
        if let file = cacheFile(for: url), let png = thumbnail.pngData() {
            try? png.write(to: file)
        }
        return thumbnail
    }

    /// Disk-only lookup for the stale-snapshot path: never spends network
    /// on data we're already presenting as stale.
    static func cachedLogo(for url: URL?) -> UIImage? {
        guard let url, let file = cacheFile(for: url),
              let data = try? Data(contentsOf: file) else { return nil }
        return UIImage(data: data)
    }

    private static func thumbnailSize(for size: CGSize) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxPixelSize, longest > 0 else { return size }
        let scale = maxPixelSize / longest
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    private static func cacheFile(for url: URL) -> URL? {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)?
            .appendingPathComponent("Library/Caches/logos", isDirectory: true)
        guard let container else { return nil }
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return container.appendingPathComponent("\(name).png")
    }
}
