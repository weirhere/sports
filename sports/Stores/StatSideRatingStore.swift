import Foundation
import Observation

/// The StatSide rating's lists, one per season (2026-10-28).
///
/// This works the way `CoachStaffStore` does. There are three copies of one
/// file, and the newest wins:
/// - the one bundled with the build, so a fresh install offline still has
///   a list;
/// - the last one downloaded, kept in Caches;
/// - `statside.co/statside-rating.json`, asked for once per launch.
///
/// The served file is what the weekly job updates
/// (`.github/workflows/statside-rating.yml`), so each Saturday's results
/// reach the app without a release.
@Observable
final class StatSideRatingStore {
    private(set) var file: StatSideRatingFile?
    @ObservationIgnored private var refreshed = false

    static let remoteURL = URL(string: "https://www.statside.co/statside-rating.json")

    private static var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("statside-rating.json")
    }

    init(bundle: Bundle = .main) {
        let bundled = bundle.url(forResource: "statside-rating", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap(Self.decode)
        let cached = Self.cacheURL
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap(Self.decode)
        file = Self.newer(bundled, cached)
    }

    /// One season's list, or nil for a season the file doesn't carry.
    func season(_ year: Int) -> StatSideRating.Season? {
        file?.season(year)
    }

    /// One request per launch; a failure keeps what's already loaded.
    func refresh() async {
        guard !refreshed, let url = Self.remoteURL else { return }
        refreshed = true
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let fetched = Self.decode(data) else { return }
        let next = Self.newer(file, fetched)
        guard next?.updated != file?.updated else { return }
        file = next
        if let cacheURL = Self.cacheURL { try? data.write(to: cacheURL, options: .atomic) }
    }

    private nonisolated static func decode(_ data: Data) -> StatSideRatingFile? {
        try? JSONDecoder().decode(StatSideRatingFile.self, from: data)
    }

    /// ISO dates compare as strings; a file with no date loses to one with.
    private static func newer(_ a: StatSideRatingFile?, _ b: StatSideRatingFile?) -> StatSideRatingFile? {
        guard let a else { return b }
        guard let b else { return a }
        return (b.updated ?? "") > (a.updated ?? "") ? b : a
    }
}
