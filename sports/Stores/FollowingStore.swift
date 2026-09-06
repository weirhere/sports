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
    /// Leagues whose poll (college football's Top 25) is followed.
    private(set) var pollLeagues: Set<League>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        teamKeys = Set(defaults.stringArray(forKey: AppGroup.followingKeysKey) ?? [])
        conferenceIds = Set(
            (defaults.stringArray(forKey: AppGroup.followingConferenceTokensKey) ?? [])
                .compactMap(ConferenceID.init(token:))
        )
        pollLeagues = Set(
            (defaults.stringArray(forKey: AppGroup.followingPollLeaguesKey) ?? [])
                .compactMap(League.init(rawValue:))
        )
    }

    /// Deliberately poll-blind: this gates the game-shaped surfaces (the
    /// Scores Following section, the reminder offer), and a followed poll
    /// carries no games — counting it would promise a Following section
    /// with nothing in it.
    var followsAnyone: Bool { !teamKeys.isEmpty || !conferenceIds.isEmpty }

    /// The league the user follows most, for search's ranking tiebreak.
    ///
    /// It replaced the Scores screen's league scope on 2026-09-05, when
    /// that scope stopped existing — the leagues share the page now. Nil
    /// on a tie or with nothing followed, which is what "no preference"
    /// means: search then ranks on the match itself.
    var preferredLeague: League? {
        var counts: [League: Int] = [:]
        for key in teamKeys {
            guard let raw = key.split(separator: ":", maxSplits: 1).first,
                  let league = League(rawValue: String(raw)) else { continue }
            counts[league, default: 0] += 1
        }
        for conference in conferenceIds {
            counts[conference.league, default: 0] += 1
        }
        let ranked = counts.sorted { $0.value > $1.value }
        guard let top = ranked.first else { return nil }
        guard ranked.count == 1 || ranked[1].value < top.value else { return nil }
        return top.key
    }

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

    func isFollowingPoll(in league: League) -> Bool {
        pollLeagues.contains(league)
    }

    func togglePoll(in league: League) {
        if pollLeagues.contains(league) {
            pollLeagues.remove(league)
        } else {
            pollLeagues.insert(league)
        }
        defaults.set(pollLeagues.map(\.rawValue).sorted(),
                     forKey: AppGroup.followingPollLeaguesKey)
        // No widget reload, for the conference set's reason: the widget is
        // team-follow-driven, so a reload here would change nothing.
    }

    /// Every followed team id within one league, unqualified — what the
    /// per-league fetchers (schedules, reminders) want.
    func teamIds(in league: League) -> Set<String> {
        let prefix = "\(league.rawValue):"
        return Set(teamKeys.compactMap { key in
            key.hasPrefix(prefix) ? String(key.dropFirst(prefix.count)) : nil
        })
    }

    /// A game is followed through either team, or through any group either
    /// side sits inside — its conference, and in the NFL the division's
    /// conference and the league above that.
    ///
    /// The walk-up is what makes an NFL conference follow mean anything:
    /// ESPN's NFL scoreboard gives a team its *division* id, so matching
    /// on the id alone never saw a followed AFC, NFC, or NFL.
    ///
    /// An FCS visitor's nil conferenceId simply doesn't match — its FBS
    /// host's side carries the game into Following.
    func follows(_ game: Game) -> Bool {
        teamKeys.contains(game.home.team.followKey)
            || teamKeys.contains(game.away.team.followKey)
            || followsConference(of: game.home.team)
            || followsConference(of: game.away.team)
    }

    private func followsConference(of team: Team) -> Bool {
        guard let conference = team.conference else { return false }
        return Conference.chain(for: conference).contains(where: conferenceIds.contains)
    }
}
