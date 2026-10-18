import SwiftUI

/// A player's photo in a quiet disc, with the jersey number showing
/// through wherever ESPN has no photo — `CoachHeadshot`'s recipe with a
/// number where the coach has initials, because on a field the number is
/// how a player is found.
struct PersonDisc: View {
    let jersey: String?
    let url: URL?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.bgElevated)
            Text(jersey ?? "")
                .font(.system(size: size * 0.34, weight: .semibold).monospacedDigit())
                .foregroundStyle(.textSecondary)
            if let url {
                LogoImage(url: url, placeholder: nil, contentMode: .fill)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
