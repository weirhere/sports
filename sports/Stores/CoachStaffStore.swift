import Foundation
import Observation

/// Each football team's coordinators and quarterbacks coach (Andy,
/// 2026-10-03: "include rows for OC, DC, QB coach and other important
/// coaching roles").
///
/// Three copies of one file, newest wins: the one bundled with the build
/// (so a fresh install offline still has staffs), the last one downloaded
/// (Caches), and `statside.co/coaches.json`, asked once per launch. The
/// served file is what a weekly job updates (`.github/workflows/
/// coaches.yml`), so a mid-season firing reaches the app without a
/// release.
@Observable
final class CoachStaffStore {
    private(set) var file: CoachStaffFile?
    @ObservationIgnored private var refreshed = false

    static let remoteURL = URL(string: "https://www.statside.co/coaches.json")

    private static var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("coaches.json")
    }

    init(bundle: Bundle = .main) {
        let bundled = bundle.url(forResource: "coaches", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap(Self.decode)
        let cached = Self.cacheURL
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap(Self.decode)
        file = Self.newer(bundled, cached)
    }

    func staff(for team: Team) -> [StaffCoach] {
        file?.staff(league: team.league, teamId: team.id) ?? []
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

    private static func decode(_ data: Data) -> CoachStaffFile? {
        try? JSONDecoder().decode(CoachStaffFile.self, from: data)
    }

    /// ISO dates compare as strings; a file with no date loses to one with.
    private static func newer(_ a: CoachStaffFile?, _ b: CoachStaffFile?) -> CoachStaffFile? {
        guard let a else { return b }
        guard let b else { return a }
        return (b.updated ?? "") > (a.updated ?? "") ? b : a
    }
}
