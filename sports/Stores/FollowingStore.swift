import Foundation
import Observation

@Observable
final class FollowingStore {
    private static let key = "following.teamIds"

    private(set) var teamIds: Set<String>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        teamIds = Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    var followsAnyone: Bool { !teamIds.isEmpty }

    func isFollowing(_ teamId: String) -> Bool {
        teamIds.contains(teamId)
    }

    func toggle(_ teamId: String) {
        if teamIds.contains(teamId) {
            teamIds.remove(teamId)
        } else {
            teamIds.insert(teamId)
        }
        defaults.set(Array(teamIds).sorted(), forKey: Self.key)
    }

    func follows(_ game: Game) -> Bool {
        teamIds.contains(game.home.team.id) || teamIds.contains(game.away.team.id)
    }
}
