import SwiftUI

/// Conference mark for section headers, full color like team logos (the
/// color budget's logo exception covers both).
/// A nil URL — the "Other" bucket, or an unknown conference id — falls back
/// to a football glyph so every conference header indents identically.
struct ConferenceLogo: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                LogoImage(url: url, placeholder: nil)
            } else {
                Image(systemName: "football")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(width: 18, height: 18)
        // Negative padding keeps the layout footprint at 18 so every
        // section title still starts at the same x.
        .background(Circle().fill(Color.logoBacking).padding(-3))
    }
}
