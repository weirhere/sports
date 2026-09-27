import SwiftUI

/// A story, read in the app (N4). FotMob's article order (N5): the photo
/// edge to edge where ESPN sent one (2026-09-27, Mobbin flow `c834c5a9`),
/// the headline, who wrote it and exactly when, the dek, the game's own
/// score row, then the text, and it ends in the teams it's about (N6).
///
/// The header sits on the card surface like the game page's and the entity
/// pages', and everything under it is cards on the recessed one.
struct StoryReader: View {
    let destination: StoryDestination

    @Environment(TeamDirectoryStore.self) private var directory: TeamDirectoryStore?
    @Environment(LeagueScoreboards.self) private var scoreboards: LeagueScoreboards?

    /// A feed item's fetched text, and the attribution the feed lacked.
    /// Keyed to the story, the game page's `loadedKey` guard: a reused
    /// reader must not print the last story's text under this headline.
    @State private var fetched: FetchedBody?
    @State private var isLoading = false
    @State private var failed = false

    private struct FetchedBody: Equatable {
        let storyId: String
        let blocks: [StoryBlock]
        let attribution: String?
    }

    private var story: NewsStory { destination.story }

    private var current: FetchedBody? { fetched?.storyId == story.id ? fetched : nil }

    private var blocks: [StoryBlock]? { story.body ?? current?.blocks }

    private var meta: String? {
        let parts = [story.attribution ?? current?.attribution,
                     story.published.map(NewsTimestamp.exact)].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The live board's copy wins: a recap opened from a schedule row still
    /// shows the final score the board has, not the snapshot it was pushed
    /// with.
    private var game: Game? {
        guard let gameId = story.gameId else { return nil }
        return scoreboards?.game(id: gameId) ?? destination.game.flatMap { $0.id == gameId ? $0 : nil }
    }

    private var teams: [Team] {
        story.teams.compactMap { directory?.team(matching: TeamRef(id: $0.id, league: story.league)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                VStack(spacing: Spacing.sm) {
                    if let game { StoryGameCard(game: game, isLink: destination.linksGame) }
                    bodySection
                    if !teams.isEmpty { StoryTeamsCard(teams: teams) }
                }
                .padding(Spacing.sm)
            }
        }
        .heroTopBand(Color.bgCard)
        .background(Color.bgRecessed)
        .navigationTitle(story.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgCard, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task(id: story.id) { await loadBody() }
    }

    private var header: some View {
        VStack(spacing: 0) {
            if story.imageURL != nil {
                StoryPhoto(url: story.imageURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
            headerText
        }
        .background(Color.bgCard)
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(story.headline)
                .font(.heroTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let meta {
                Text(meta)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
            if let dek = story.dek {
                Text(dek)
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.bgCard)
    }

    @ViewBuilder
    private var bodySection: some View {
        if let blocks {
            StoryBodyCard(blocks: blocks)
        } else if failed {
            StatusMessage(text: "Couldn't load this story.",
                          retry: { Task { await loadBody(force: true) } })
                .cardSurface()
        } else {
            // A lone spinner gets no card (Andy, 2026-08-31).
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
        }
    }

    /// One request, and only for a feed item: a story from the game summary
    /// arrived with its text. Never polled — a story doesn't change while
    /// it's being read.
    private func loadBody(force: Bool = false) async {
        guard story.body == nil, force || current == nil, !isLoading else { return }
        let key = story.id
        isLoading = true
        failed = false
        defer { isLoading = false }
        let loaded = await NewsClient().body(of: story)
        guard story.id == key else { return }
        if let loaded {
            fetched = FetchedBody(storyId: key, blocks: loaded.blocks, attribution: loaded.attribution)
        } else {
            failed = true
        }
    }
}
