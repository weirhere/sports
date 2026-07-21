import SwiftUI

/// One team in the browse list: logo, name, follow star. The row navigates;
/// the star doesn't.
struct TeamBrowseRow: View {
    let team: Team

    var body: some View {
        HStack(spacing: Spacing.md) {
            NavigationLink(value: team) {
                HStack(spacing: Spacing.md) {
                    AsyncImage(url: team.logoURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Circle().fill(Color.bgElevated)
                    }
                    .frame(width: 26, height: 26)
                    Text(team.location)
                        .font(.teamName)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    if let nickname = team.name {
                        Text(nickname)
                            .font(.meta)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            FollowButton(teamId: team.id)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 5)
    }
}
