import SwiftUI

/// A coach's photo in a disc, or their initials where ESPN has no photo.
///
/// ESPN's only coach headshot is a 65px JPEG
/// (`headshots/{league}/coaches/65/{id}.jpg`); the `full/` path players use
/// 404s for every coach, so there is no larger asset to ask for.
struct CoachHeadshot: View {
    let name: String
    let url: URL?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.bgElevated)
            // Always drawn, under the photo: the Roster row guesses a URL
            // that 404s for most coaches (2026-10-03), and a miss should
            // read as initials, not an empty disc.
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(.textSecondary)
            if let url {
                LogoImage(url: url, placeholder: nil, contentMode: .fill)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    /// "TB" for Todd Bowles; the first and last words, so "Jim Harbaugh"
    /// and "Kalen DeBoer" read the same and a suffix can't become a letter.
    private var initials: String {
        let words = name.split(separator: " ").filter { !["Jr.", "Sr.", "II", "III", "IV"].contains($0) }
        let letters = [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first }
        return String(letters).uppercased()
    }
}
