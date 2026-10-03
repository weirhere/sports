import Foundation
import Observation

/// One kind of notification a team can send.
///
/// Per team, from the bell on its page (Andy, 2026-09-28, FotMob's "Set
/// notifications" sheet). Only the kickoff reminder is sent by the phone
/// itself; every other case needs a server watching ESPN while the app is
/// closed, and is offered only once `serviceIsAvailable` says one exists. A
/// row that can't fire would be a promise the app doesn't keep.
nonisolated enum TeamAlert: String, CaseIterable, Codable, Sendable, Identifiable {
    case kickoffReminder = "kickoff"
    case gameStart = "start"
    case scoring
    /// Halftime in football and basketball, intermissions in hockey.
    case breakInPlay = "break"
    case final
    case news

    var id: String { rawValue }

    /// Scheduled locally from the team's schedule, no server involved.
    var isLocal: Bool { self == .kickoffReminder }

    /// False until something sends live alerts. DEBUG builds may switch it
    /// on to look at the full sheet — the `liveactivity.enabled` pattern.
    static var serviceIsAvailable: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "alerts.service.enabled") { return true }
        #endif
        return false
    }

    /// The rows a team in `league` offers, in the sheet's order.
    static func offered(in league: League,
                        serviceAvailable: Bool = TeamAlert.serviceIsAvailable) -> [TeamAlert] {
        allCases.filter { $0.applies(to: league) && ($0.isLocal || serviceAvailable) }
    }

    /// A basketball game scores 200 points; an alert per basket is noise,
    /// and "scoring" has no quieter meaning there that the payload carries.
    func applies(to league: League) -> Bool {
        switch (self, league) {
        case (.scoring, .nba): false
        default: true
        }
    }

    func title(in league: League) -> String {
        switch self {
        case .kickoffReminder: "30 min before \(league.startNoun.lowercased())"
        case .gameStart: league.startNoun
        case .scoring: league == .nhl ? "Goals" : "Scoring plays"
        case .breakInPlay: league == .nhl ? "Intermissions" : "Halftime"
        case .final: "Final score"
        case .news: "News"
        }
    }

    func symbol(in league: League) -> String {
        switch self {
        case .kickoffReminder: "alarm"
        case .gameStart: "play.circle"
        case .scoring: league == .nhl ? "hockey.puck" : "football"
        case .breakInPlay: "pause.circle"
        case .final: "flag.checkered"
        case .news: "newspaper"
        }
    }
}

/// What each team sends: its alerts, a per-team mute, and whether its games
/// pin to the Lock Screen.
///
/// Keyed by follow key (`"nfl:26"`), and only teams the user has touched
/// are stored. An untouched team reads `defaultAlerts`, the kickoff reminder
/// alone, which is exactly what every followed team got before this sheet
/// existed. The mute is separate from the choices so switching a team off
/// and on again gives back what was picked.
///
/// The app-wide switch (`NotificationScheduler.remindersOn`, Settings) and
/// the system permission still sit above all of it.
@Observable
final class TeamAlertStore {
    static let defaultAlerts: Set<TeamAlert> = [.kickoffReminder]

    private static let alertsKey = "notifications.teamAlerts"
    private static let mutedKey = "notifications.mutedTeams"
    private static let pinnedKey = "notifications.pinnedTeams"

    private(set) var chosen: [String: Set<TeamAlert>]
    private(set) var muted: Set<String>
    private(set) var pinned: Set<String>
    /// Bumps on every write, so `RootView` resyncs once per change rather
    /// than diffing three collections.
    private(set) var revision = 0

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.dictionary(forKey: Self.alertsKey) as? [String: [String]] ?? [:]
        chosen = raw.mapValues { Set($0.compactMap(TeamAlert.init(rawValue:))) }
        muted = Set(defaults.stringArray(forKey: Self.mutedKey) ?? [])
        pinned = Set(defaults.stringArray(forKey: Self.pinnedKey) ?? [])
    }

    // MARK: - Reading

    func alerts(for key: String) -> Set<TeamAlert> {
        chosen[key] ?? Self.defaultAlerts
    }

    func isMuted(_ key: String) -> Bool { muted.contains(key) }

    /// Whether this team sends `alert` now: chosen and not muted.
    func isOn(_ alert: TeamAlert, for key: String) -> Bool {
        !isMuted(key) && alerts(for: key).contains(alert)
    }

    /// Whether any row the team's sheet offers is on — the bell's glyph.
    func sendsAnything(_ key: String, in league: League,
                       serviceAvailable: Bool = TeamAlert.serviceIsAvailable) -> Bool {
        TeamAlert.offered(in: league, serviceAvailable: serviceAvailable)
            .contains { isOn($0, for: key) }
    }

    func pinsGames(_ key: String) -> Bool { pinned.contains(key) }

    /// The followed teams that send `alert`. What the kickoff scheduler is
    /// handed in place of the whole follow set.
    func keys(receiving alert: TeamAlert, among followed: Set<String>) -> Set<String> {
        followed.filter { isOn(alert, for: $0) }
    }

    func pinnedKeys(among followed: Set<String>) -> Set<String> {
        followed.intersection(pinned)
    }

    // MARK: - Writing

    func toggle(_ alert: TeamAlert, for key: String) {
        var set = alerts(for: key)
        if set.contains(alert) { set.remove(alert) } else { set.insert(alert) }
        chosen[key] = set
        defaults.set(chosen.mapValues { $0.map(\.rawValue).sorted() }, forKey: Self.alertsKey)
        revision += 1
    }

    func setMuted(_ isMuted: Bool, for key: String) {
        guard isMuted != muted.contains(key) else { return }
        if isMuted { muted.insert(key) } else { muted.remove(key) }
        defaults.set(muted.sorted(), forKey: Self.mutedKey)
        revision += 1
    }

    func setPinsGames(_ pins: Bool, for key: String) {
        guard pins != pinned.contains(key) else { return }
        if pins { pinned.insert(key) } else { pinned.remove(key) }
        defaults.set(pinned.sorted(), forKey: Self.pinnedKey)
        revision += 1
    }
}
