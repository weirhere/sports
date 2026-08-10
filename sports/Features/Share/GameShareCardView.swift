import SwiftUI

/// The matchup card a share carries: GameDetail's header shape — logos left
/// and right, status stacked in the middle — rendered to a PNG so a message
/// thread shows the game itself instead of the generic App Store card.
///
/// Pure and synchronous by design. `ImageRenderer` never runs `.task`, so
/// logos arrive as pre-fetched `UIImage`s, never through `LogoImage`. Fonts
/// are fixed sizes, not the theme's tokens — those scale with the sharer's
/// Dynamic Type setting, and the artifact should look the same from every
/// phone. Colors still come from the semantic tokens; the render site forces
/// light mode so the card reads on any message background.
struct GameShareCardView: View {
    struct Side {
        let name: String
        let record: String?
        let score: Int?
        let rank: Int?
        let winner: Bool?
        let logo: UIImage?
    }

    let away: Side
    let home: Side
    let statusLine: String
    let showsScores: Bool
    let isLive: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.lg) {
                side(away)
                VStack(spacing: Spacing.sm) {
                    if isLive {
                        // A static stand-in for LiveDot: same size, same
                        // accent, no pulse for the renderer to catch mid-dim.
                        Circle()
                            .fill(.liveAccent)
                            .frame(width: 8, height: 8)
                    }
                    Text(statusLine)
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xl)
                side(home)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.lg)

            Divider().overlay(Color.divider)

            // Attribution lives on the card, mirroring ScoresHeader's wordmark.
            HStack(spacing: Spacing.xs + 2) {
                Image(systemName: "football.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("StatSide")
                    .font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(.textPrimary)
            .padding(.vertical, Spacing.md)
        }
        .background(Color.bgPrimary)
    }

    private func side(_ side: Side) -> some View {
        VStack(spacing: Spacing.sm) {
            logo(side.logo)
                .frame(width: 72, height: 72)
            Text(rankedName(side))
                .font(.system(size: 22, weight: side.winner == true ? .semibold : .regular))
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                // Reserved so a wrapping name doesn't push its record
                // below the other side's — same trick as the detail header.
                .lineLimit(2, reservesSpace: true)
            if let record = side.record {
                Text(record)
                    .font(.system(size: 17))
                    .monospacedDigit()
                    .foregroundStyle(.textSecondary)
            }
            if showsScores, let score = side.score {
                Text("\(score)")
                    .font(.system(size: 40, weight: isLive ? .heavy : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(side.winner == false ? .textSecondary : .textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func rankedName(_ side: Side) -> String {
        guard let rank = side.rank else { return side.name }
        return "#\(rank) \(side.name)"
    }

    @ViewBuilder
    private func logo(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            // Offline / never-fetched: the quiet placeholder, same as
            // LogoImage's — a share should degrade, never fail.
            Circle().fill(Color.bgElevated)
        }
    }
}

#Preview("Final") {
    GameShareCardView(
        away: .init(name: "Vanderbilt", record: "9-2", score: 31, rank: 9, winner: false, logo: nil),
        home: .init(name: "Texas", record: "8-3", score: 34, rank: 20, winner: true, logo: nil),
        statusLine: "Final",
        showsScores: true,
        isLive: false)
        .frame(width: 600)
}

#Preview("Live") {
    GameShareCardView(
        away: .init(name: "Georgia", record: "7-0", score: 24, rank: 5, winner: nil, logo: nil),
        home: .init(name: "Florida", record: "4-3", score: 20, rank: nil, winner: nil, logo: nil),
        statusLine: "Q3 5:24",
        showsScores: true,
        isLive: true)
        .frame(width: 600)
}

#Preview("Pre") {
    GameShareCardView(
        away: .init(name: "Ball State", record: "0-0", score: nil, rank: nil, winner: nil, logo: nil),
        home: .init(name: "Ohio State", record: "0-0", score: nil, rank: 1, winner: nil, logo: nil),
        statusLine: "Sat, Sep 5 at 12:30 PM\nBTN",
        showsScores: false,
        isLive: false)
        .frame(width: 600)
}

#Preview("Postponed") {
    GameShareCardView(
        away: .init(name: "Rice", record: "2-4", score: nil, rank: nil, winner: nil, logo: nil),
        home: .init(name: "Memphis", record: "6-1", score: nil, rank: 25, winner: nil, logo: nil),
        statusLine: "Postponed",
        showsScores: false,
        isLive: false)
        .frame(width: 600)
}
