import SwiftUI

/// A News page's section heading: a 20pt mark and a name, in
/// `ListSectionHeading`'s type and spacing, with room at the trailing edge
/// for a link. For you's team sections and the Leagues page's leagues.
struct NewsSectionHeading<Trailing: View>: View {
    let logoURL: URL?
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                LogoImage(url: logoURL)
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            trailing
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xs)
    }
}

extension NewsSectionHeading where Trailing == EmptyView {
    init(logoURL: URL?, title: String) {
        self.init(logoURL: logoURL, title: title) { EmptyView() }
    }
}
