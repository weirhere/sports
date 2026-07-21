import SwiftUI

/// One team in the browse list: logo, name, follow star. The row navigates;
/// the star doesn't.
struct TeamBrowseRow: View {
    let team: Team

    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26

    var body: some View {
        HStack(spacing: Spacing.md) {
            NavigationLink(value: team) {
                HStack(spacing: Spacing.md) {
                    LogoImage(url: team.logoURL)
                        .frame(width: logoSize, height: logoSize)
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(team.displayName ?? team.location)
            }
            .buttonStyle(.plain)
            FollowButton(teamId: team.id)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 5)
    }
}
