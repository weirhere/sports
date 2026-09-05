import Foundation
import Observation
import UserNotifications

/// The slice of UNUserNotificationCenter the scheduler needs, value-typed
/// so tests inject a fake — same pattern as `ScoreboardStore(client:)`.
nonisolated protocol NotificationCentering: Sendable {
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func pendingIdentifiers() async -> [String]
    func add(id: String, title: String, body: String, fireDate: Date, gameId: String) async throws
    func removePending(identifiers: [String]) async
}

nonisolated struct SystemNotificationCenter: NotificationCentering {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func add(id: String, title: String, body: String, fireDate: Date, gameId: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["gameId": gameId]
        // An interval from an absolute instant, not a calendar trigger:
        // kickoff doesn't move when the user changes timezone.
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func removePending(identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// Kickoff reminders for followed teams: one local notification per game,
/// 30 minutes before kickoff, capped well under iOS's 64-pending limit.
/// Request ids encode the kickoff instant, so moved kickoffs, cancellations,
/// and TBD-times-becoming-real all fall out of a pending-vs-desired diff
/// with zero special cases.
@Observable
final class NotificationScheduler {
    static let leadTime: TimeInterval = 30 * 60
    static let maxScheduled = 24
    private static let idPrefix = "kickoff."
    private static let enabledKey = "notifications.enabled"

    /// The user turned reminders on AND the system still authorizes them.
    private(set) var remindersOn = false
    /// The system permission was denied — the bell routes to Settings.
    private(set) var isDenied = false

    private let center: any NotificationCentering
    /// One client per league — a followed team's schedule lives behind its
    /// own league's endpoint. Injected as a factory so tests can hand over
    /// a single stub for both.
    private let makeClient: @Sendable (League) -> any ScoresProviding
    private let defaults: UserDefaults

    init(center: any NotificationCentering = SystemNotificationCenter(),
         makeClient: @escaping @Sendable (League) -> any ScoresProviding = {
             DataProvider.makeClient(league: $0)
         },
         defaults: UserDefaults = .standard) {
        self.center = center
        self.makeClient = makeClient
        self.defaults = defaults
    }

    /// Convenience for tests and previews that only care about one backend.
    convenience init(center: any NotificationCentering = SystemNotificationCenter(),
                     client: any ScoresProviding,
                     defaults: UserDefaults = .standard) {
        self.init(center: center, makeClient: { _ in client }, defaults: defaults)
    }

    /// Re-checks system authorization — called on scene-active so the bell
    /// never lies after a round trip through Settings.
    func refreshAuthorization() async {
        let status = await center.authorizationStatus()
        isDenied = status == .denied
        let authorized = status == .authorized || status == .provisional
        remindersOn = authorized && defaults.bool(forKey: Self.enabledKey)
        if !authorized {
            await center.removePending(identifiers: pendingKickoffIds())
        }
    }

    /// The bell's turn-on path (and the post-first-follow prompt's).
    /// Returns false when the system says no — the caller shows nothing;
    /// the bell's denied state carries the message.
    @discardableResult
    func requestAndEnable(followedKeys: Set<String>) async -> Bool {
        let granted = (try? await center.requestAuthorization()) ?? false
        isDenied = !granted
        defaults.set(granted, forKey: Self.enabledKey)
        remindersOn = granted
        if granted {
            await resync(followedKeys: followedKeys)
        }
        return granted
    }

    func disable() async {
        defaults.set(false, forKey: Self.enabledKey)
        remindersOn = false
        await center.removePending(identifiers: pendingKickoffIds())
    }

    /// Rebuilds the pending set from followed teams' schedules. Cheap on
    /// the API — one schedule fetch per followed team, only when follows
    /// change, the scene activates, or reminders turn on.
    ///
    /// Keys are league-qualified (`"cfb:130"`, `"nfl:26"`), because ESPN
    /// team ids collide across leagues and a bare id would fetch the wrong
    /// team's schedule. The nearest-24 cap is deliberately shared across
    /// leagues: the next kickoffs win, whichever sport they belong to.
    func resync(followedKeys: Set<String>) async {
        guard remindersOn else { return }
        guard !followedKeys.isEmpty else {
            await center.removePending(identifiers: pendingKickoffIds())
            return
        }

        var gamesById: [String: Game] = [:]
        for key in followedKeys {
            let parts = key.split(separator: ":", maxSplits: 1)
            // A bare id predates the league axis and means college football.
            let league = parts.count == 2 ? League(rawValue: String(parts[0])) : .collegeFootball
            guard let league else { continue }
            let teamId = parts.count == 2 ? String(parts[1]) : key
            guard let schedule = try? await makeClient(league).teamSchedule(teamId: teamId)
            else { continue }
            for game in schedule.games {
                // Dedupe by game id: both-teams-followed games get one
                // reminder. TBD kickoffs (nil date, or a placeholder date
                // with `timeTBD`) are skipped and picked up automatically
                // once ESPN publishes a time — the kickoff-encoding request
                // id makes that a plain pending-vs-desired diff.
                gamesById[game.id] = game
            }
        }

        let now = Date.now
        let upcoming = gamesById.values
            .filter { game in
                guard case .pre = game.status, let date = game.date, !game.timeTBD
                else { return false }
                return date.addingTimeInterval(-Self.leadTime) > now
            }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
            .prefix(Self.maxScheduled)

        var desired: [String: Game] = [:]
        for game in upcoming {
            guard let date = game.date else { continue }
            desired[Self.requestId(gameId: game.id, kickoff: date)] = game
        }

        let pending = await pendingKickoffIds()
        let stale = pending.filter { desired[$0] == nil }
        if !stale.isEmpty {
            await center.removePending(identifiers: stale)
        }
        let pendingSet = Set(pending)
        for (id, game) in desired where !pendingSet.contains(id) {
            guard let date = game.date else { continue }
            try? await center.add(
                id: id,
                title: "Kickoff soon",
                body: Self.reminderBody(for: game),
                fireDate: date.addingTimeInterval(-Self.leadTime),
                gameId: game.id
            )
        }
    }

    static func requestId(gameId: String, kickoff: Date) -> String {
        "\(idPrefix)\(gameId).\(Int(kickoff.timeIntervalSince1970))"
    }

    static func reminderBody(for game: Game) -> String {
        let matchup = "\(game.away.team.location) at \(game.home.team.location)"
        let time = game.date.map { $0.formatted(date: .omitted, time: .shortened) }
        var body = matchup
        if let time {
            body += " kicks off at \(time)"
        } else {
            body += " kicks off soon"
        }
        if let broadcast = game.broadcast {
            let network = broadcast.split(separator: "/").first.map(String.init) ?? broadcast
            body += " on \(network)"
        }
        return body
    }

    private func pendingKickoffIds() async -> [String] {
        await center.pendingIdentifiers().filter { $0.hasPrefix(Self.idPrefix) }
    }
}
