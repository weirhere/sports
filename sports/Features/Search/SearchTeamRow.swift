import SwiftUI

/// A team result on the search cover. A plain button, not a NavigationLink —
/// search navigates by dismissing and handing the Router a pending intent,
/// the same rails widget taps ride.
struct SearchTeamRow: View {
    let team: Team
    let onSelect: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                LogoImage(url: team.logoURL)
                    .frame(width: logoSize, height: logoSize)
                if isStacked {
                    VStack(alignment: .leading, spacing: 2) {
                        locationText
                        nicknameText
                    }
                } else {
                    locationText
                    nicknameText
                }
                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            // Inside the label, like TeamBrowseRow: flattening outside the
            // Button would strip its button trait from the merged element.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(team.displayName ?? team.location)
        }
        .buttonStyle(.plain)
    }

    private var locationText: some View {
        Text(team.location)
            .font(.teamName)
            .foregroundStyle(.textPrimary)
            .lineLimit(isStacked ? 2 : 1)
    }

    @ViewBuilder
    private var nicknameText: some View {
        if let nickname = team.name {
            Text(nickname)
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .lineLimit(isStacked ? 2 : 1)
        }
    }
}
