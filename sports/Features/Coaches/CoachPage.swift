import SwiftUI

/// One head coach's page: Profile, Career and Games (E27, 2026-09-27).
///
/// `PlayerPage`'s template, addressed to a coach. The door is the Roster
/// tab's Coach card, which knows an id, a name and the team; everything
/// else is one `CoachClient.career` walk of ESPN's core API.
///
/// **One league per page.** ESPN keys coaches per league with nothing
/// joining them (Harbaugh is NFL `27` and a different id at Michigan), so
/// the career here is the career in this league. Joining college to pro is
/// E27's crosswalk, which isn't built.
struct CoachPage: View {
    let coach: CoachIdentity

    enum Tab: Int, CaseIterable, HeroTabItem {
        case profile, career, games

        var title: String {
            switch self {
            case .profile: "Profile"
            case .career: "Career"
            case .games: "Games"
            }
        }
    }

    @State private var career: CoachClient.Career?
    @State private var failed = false
    @State private var tab: Tab = .profile
    @State private var teamHexLoaded: String?
    @Environment(\.colorScheme) private var colorScheme

    /// The team's color in light mode, as on PlayerPage (2026-10-03).
    private var headerPaint: HeaderPaint? {
        HeaderPaint(hex: teamHexLoaded ?? HeaderPaint.teamHex(for: coach.team),
                    colorScheme: colorScheme)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    CoachHero(coach: coach, headshotURL: career?.profile.headshotURL,
                              paint: headerPaint)
                    HeroTabBar(tabs: Tab.allCases, selection: tab, onSelect: { tab = $0 },
                               ink: headerPaint?.ink, secondaryInk: headerPaint?.secondaryInk)
                }
                .frame(maxWidth: .infinity)
                .background(headerPaint?.background ?? .bgCard)

                VStack(spacing: Spacing.sm) {
                    content
                }
                .padding(Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
        // The entity pages' header, as on PlayerPage.
        .headerChrome(headerPaint)
        .background(Color.bgRecessed)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: coach.team?.followKey) {
            teamHexLoaded = await HeaderPaint.loadTeamHex(for: coach.team)
        }
        // Keyed by coach: a destination reused with its state intact would
        // otherwise keep the last coach's career (2026-09-10's rule).
        .task(id: coach.id) {
            career = nil
            await load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let career {
            switch tab {
            case .profile:
                CoachProfilePane(profile: career.profile, league: coach.league)
            case .career:
                CoachCareerPane(profile: career.profile, teams: career.teams, league: coach.league)
            case .games:
                CoachGamesPane(seasons: career.profile.seasons, teams: career.teams,
                               league: coach.league)
            }
        } else if failed {
            StatusMessage(text: "Couldn't load \(coach.name)'s career.",
                          retry: { Task { await load() } })
                .cardSurface()
        } else {
            ProgressView().padding(.vertical, Spacing.xl)
        }
    }

    private func load() async {
        failed = false
        if let loaded = await CoachClient().career(coachId: coach.coachId, league: coach.league) {
            career = loaded
        } else {
            failed = true
        }
    }
}
