import SwiftUI

/// The badge on a section header — a conference mark, or a league's own
/// (Scores' league accordions and the Tables hub's, 2026-09-06). Full color
/// like team logos; the color budget's logo exception covers all three.
/// A nil URL — the "Other" bucket, an unknown conference id, FCS — falls
/// back to a football glyph so every header title indents identically.
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
