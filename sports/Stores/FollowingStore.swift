import Foundation
import Observation
import WidgetKit

@Observable
final class FollowingStore {
    private(set) var teamIds: Set<String>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        teamIds = Set(defaults.stringArray(forKey: AppGroup.followingKey) ?? [])
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
        defaults.set(Array(teamIds).sorted(), forKey: AppGroup.followingKey)
        // A newly followed team should appear on the home screen now, not at
        // the next scheduled reload.
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
    }

    func follows(_ game: Game) -> Bool {
        teamIds.contains(game.home.team.id) || teamIds.contains(game.away.team.id)
    }
}
