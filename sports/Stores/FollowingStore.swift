import Foundation
import Observation
import WidgetKit

@Observable
final class FollowingStore {
    private(set) var teamIds: Set<String>
    private(set) var conferenceIds: Set<Int>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        teamIds = Set(defaults.stringArray(forKey: AppGroup.followingKey) ?? [])
        conferenceIds = Set(
            defaults.array(forKey: AppGroup.followingConferencesKey) as? [Int] ?? []
        )
    }

    var followsAnyone: Bool { !teamIds.isEmpty || !conferenceIds.isEmpty }

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

    func isFollowingConference(_ conferenceId: Int) -> Bool {
        conferenceIds.contains(conferenceId)
    }

    func toggleConference(_ conferenceId: Int) {
        if conferenceIds.contains(conferenceId) {
            conferenceIds.remove(conferenceId)
        } else {
            conferenceIds.insert(conferenceId)
        }
        defaults.set(Array(conferenceIds).sorted(), forKey: AppGroup.followingConferencesKey)
        // No widget reload: the widget is team-follow-driven in v1, so a
        // reload here would spend its budget to change nothing.
    }

    /// A game is followed through either team or either side's conference.
    /// An FCS visitor's nil conferenceId simply doesn't match — its FBS
    /// host's side carries the game into Following.
    func follows(_ game: Game) -> Bool {
        teamIds.contains(game.home.team.id) || teamIds.contains(game.away.team.id)
            || game.home.team.conferenceId.map(conferenceIds.contains) ?? false
            || game.away.team.conferenceId.map(conferenceIds.contains) ?? false
    }
}
