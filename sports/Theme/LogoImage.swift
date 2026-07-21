import SwiftUI

/// A logo loaded through `LogoCache`: renders instantly when the same mark
/// appears in several sections and retries on reappearance after a failed
/// fetch — the two things `AsyncImage` can't do. A nil URL or failed load
/// leaves the quiet placeholder, never a broken image. Callers size it with
/// `.frame`, matching the old `AsyncImage` call sites.
struct LogoImage: View {
    let url: URL?
    var placeholder: Color? = Color.bgElevated

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let placeholder {
                Circle().fill(placeholder)
            } else {
                Color.clear
            }
        }
        // task(id:) restarts on every appearance, so a row that failed
        // mid-blip retries when it scrolls back into view or its section
        // re-expands.
        .task(id: url) {
            guard image == nil, let url else { return }
            image = await LogoCache.shared.image(for: url)
        }
    }
}
