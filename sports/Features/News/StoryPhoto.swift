import SwiftUI

/// A story's photo, cropped to whatever frame it's given. Full color: news
/// photography is the color budget's sixth exception (Andy, 2026-09-27), and
/// only story cards, rows and the reader's hero draw it.
///
/// `AsyncImage` rather than `LogoImage`: a photo has no dark variant to
/// swap to and no outline to stamp, and URLCache holds what scrolled past.
/// Until it lands, and if it never does, the frame is the elevated gray a
/// logo waits on.
struct StoryPhoto: View {
    let url: URL?

    var body: some View {
        Color.bgElevated
            .overlay {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}
