import SwiftUI

/// A News page's section heading: a 20pt mark and a name at
/// `newsSectionTitle` (Andy, 2026-10-19, up from the list heading's 15),
/// in `ListSectionHeading`'s spacing, with room at the trailing edge for a
/// link. For you's Trending and team sections, and the Leagues page's
/// leagues.
struct NewsSectionHeading<Trailing: View>: View {
    let logoURL: URL?
    let title: String
    /// Trending has no mark; a placeholder disc would claim it did.
    var showsLogo = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                if showsLogo {
                    LogoImage(url: logoURL)
                        .frame(width: 20, height: 20)
                }
                Text(title)
                    .font(.newsSectionTitle)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
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

    /// A heading with no mark: Trending.
    init(title: String) {
        self.init(logoURL: nil, title: title, showsLogo: false) { EmptyView() }
    }
}
