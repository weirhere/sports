import SwiftUI

/// One ranked team: rank, logo, name, first-place votes, record, movement.
/// Movement shows through weight, never color.
struct RankRow: View {
    let ranked: RankedTeam

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("\(ranked.current)")
                .font(.score)
                .foregroundStyle(.textPrimary)
                .frame(width: 26, alignment: .trailing)
            AsyncImage(url: ranked.team.logoURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Circle().fill(Color.bgElevated)
            }
            .frame(width: 22, height: 22)
            Text(ranked.team.location)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            if let votes = ranked.firstPlaceVotes, votes > 0 {
                Text("(\(votes))")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
            Spacer()
            if let record = ranked.record {
                Text(record)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
            movementLabel
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var movementLabel: some View {
        switch ranked.movement {
        case .some(let delta) where delta > 0:
            Text("▲ \(delta)")
                .font(.metaEmphasis)
                .foregroundStyle(.textPrimary)
        case .some(let delta) where delta < 0:
            Text("▼ \(-delta)")
                .font(.metaEmphasis)
                .foregroundStyle(.textPrimary)
        case .some:
            Text("–")
                .font(.meta)
                .foregroundStyle(.textSecondary)
        case nil:
            Text("NEW")
                .font(.metaEmphasis)
                .foregroundStyle(.textSecondary)
        }
    }
}
