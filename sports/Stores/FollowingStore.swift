import Foundation
import Observation
import WidgetKit

@Observable
final class FollowingStore {
    /// League-qualified follow keys (`"cfb:130"`, `"nfl:26"`). ESPN team ids
    /// collide across leagues — 26 is UCLA in college football and the
    /// Seahawks in the NFL — so a bare id was never safe to store once a
    /// second league existed. Migrated once from the pre-league set.
    private(set) var teamKeys: Set<String>
    private(set) var conferenceIds: Set<ConferenceID>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        teamKeys = Set(defaults.stringArray(forKey: AppGroup.followingKeysKey) ?? [])
        conferenceIds = Set(
            (defaults.stringArray(forKey: AppGroup.followingConferenceTokensKey) ?? [])
                .compactMap(ConferenceID.init(token:))
        )
    }

    var followsAnyone: Bool { !teamKeys.isEmpty || !conferenceIds.isEmpty }

    func isFollowing(_ team: Team) -> Bool {
        teamKeys.contains(team.followKey)
    }

    func isFollowing(_ teamId: String, in league: League) -> Bool {
        teamKeys.contains("\(league.rawValue):\(teamId)")
    }

    func toggle(_ team: Team) {
        toggle(team.id, in: team.league)
    }

    func toggle(_ teamId: String, in league: League) {
        let key = "\(league.rawValue):\(teamId)"
        if teamKeys.contains(key) {
            teamKeys.remove(key)
        } else {
            teamKeys.insert(key)
        }
        defaults.set(Array(teamKeys).sorted(), forKey: AppGroup.followingKeysKey)
        // A newly followed team should appear on the home screen now, not at
        // the next scheduled reload.
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.widgetKind)
    }

    func isFollowingConference(_ conference: ConferenceID) -> Bool {
        conferenceIds.contains(conference)
    }

    func toggleConference(_ conference: ConferenceID) {
        if conferenceIds.contains(conference) {
            conferenceIds.remove(conference)
        } else {
            conferenceIds.insert(conference)
        }
        defaults.set(conferenceIds.map(\.token).sorted(),
                     forKey: AppGroup.followingConferenceTokensKey)
        // No widget reload: the widget is team-follow-driven in v1, so a
        // reload here would spend its budget to change nothing.
    }

    /// Every followed team id within one league, unqualified — what the
    /// per-league fetchers (schedules, reminders) want.
    func teamIds(in league: League) -> Set<String> {
        let prefix = "\(league.rawValue):"
        return Set(teamKeys.compactMap { key in
            key.hasPrefix(prefix) ? String(key.dropFirst(prefix.count)) : nil
        })
    }

    /// A game is followed through either team or either side's conference.
    /// An FCS visitor's nil conferenceId simply doesn't match — its FBS
    /// host's side carries the game into Following.
    func follows(_ game: Game) -> Bool {
        teamKeys.contains(game.home.team.followKey)
            || teamKeys.contains(game.away.team.followKey)
            || game.home.team.conference.map(conferenceIds.contains) ?? false
            || game.away.team.conference.map(conferenceIds.contains) ?? false
    }
}
