import Foundation
import Observation

/// Each school's players in the NFL, NBA and NHL, for the college team
/// page's Pros tab (2026-11-02).
///
/// `CoachStaffStore`'s three copies, newest wins: the one bundled with the
/// build (so a fresh install offline still has the tab), the last one
/// downloaded (Caches), and `statside.co/pros.json`, asked once per launch.
/// The served file is what `.github/workflows/pros.yml` rebuilds weekly from
/// ESPN's pro rosters, so a signing reaches the app without a release.
///
/// **Unlike the coaches' file, nothing is decoded in `init`.** This one is
/// ~650 KB, and `RootView` builds its stores on the main thread at launch —
/// the one moment the app is promising to be fast. `refresh()` decodes off
/// the main actor; a page opened in the half-second before it lands simply
/// has no Pros tab yet, and gains it when the file does.
@Observable
final class ProAlumniStore {
    private(set) var file: ProAlumniFile?
    @ObservationIgnored private var refreshed = false
    @ObservationIgnored private let bundle: Bundle

    static let remoteURL = URL(string: "https://www.statside.co/pros.json")

    private static var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("pros.json")
    }

    /// `file` is for tests: a store that starts loaded, before `refresh()`.
    init(bundle: Bundle = .main, file: ProAlumniFile? = nil) {
        self.bundle = bundle
        self.file = file
    }

    /// The school's pros. Empty for anything but a college football team:
    /// a pro team has no alumni, and its id would collide with a school's.
    func alumni(of team: Team) -> [ProAlumnus] {
        guard team.league == .collegeFootball else { return [] }
        return file?.alumni(collegeId: team.id) ?? []
    }

    /// The local copies, then one request per launch; a failure keeps
    /// what's already loaded.
    func refresh() async {
        guard !refreshed else { return }
        refreshed = true
        let local = await Self.loadLocal(bundleURL: bundle.url(forResource: "pros", withExtension: "json"))
        file = Self.newer(file, local)

        guard let url = Self.remoteURL,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let fetched = await Self.decode(data) else { return }
        let next = Self.newer(file, fetched)
        guard next?.updated != file?.updated else { return }
        file = next
        if let cacheURL = Self.cacheURL { try? data.write(to: cacheURL, options: .atomic) }
    }

    @concurrent
    private static func loadLocal(bundleURL: URL?) async -> ProAlumniFile? {
        let bundled = bundleURL.flatMap { try? Data(contentsOf: $0) }.flatMap(decodeSync)
        let cached = cacheURL.flatMap { try? Data(contentsOf: $0) }.flatMap(decodeSync)
        return newer(bundled, cached)
    }

    @concurrent
    private static func decode(_ data: Data) async -> ProAlumniFile? {
        decodeSync(data)
    }

    nonisolated private static func decodeSync(_ data: Data) -> ProAlumniFile? {
        try? JSONDecoder().decode(ProAlumniFile.self, from: data)
    }

    /// ISO dates compare as strings; a file with no date loses to one with.
    nonisolated static func newer(_ a: ProAlumniFile?, _ b: ProAlumniFile?) -> ProAlumniFile? {
        guard let a else { return b }
        guard let b else { return a }
        return (b.updated ?? "") > (a.updated ?? "") ? b : a
    }
}
