import LinkPresentation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// One rich bubble instead of three things.
///
/// A game share used to land in a thread as a PNG, a text bubble, and an
/// App Store link preview wearing the store's stock product shot — the
/// only visual being a picture of the app, next to the picture of the game
/// nobody linked it to. `LPLinkMetadata` lets the *sender* supply the
/// preview image, so the link itself can wear the real matchup card.
///
/// This supersedes the 2026-08-09 conclusion that repointing the preview
/// needed per-game web pages and therefore a backend. It needs neither.
///
/// `ShareLink` can't vend link metadata, so the toolbar share drops to
/// UIKit — the app's second UIKit exception, after the notification bell's
/// `openNotificationSettingsURLString` (Andy, 2026-09-05).
final class GameShareItemSource: NSObject, UIActivityItemSource {
    /// The score line: "Final: Bethune-Cookman 6, UCF 73".
    let title: String
    let link: URL
    /// The rendered matchup card as PNG bytes. Nil only if the render
    /// failed, and then the bubble degrades to a plain titled link rather
    /// than to nothing.
    ///
    /// Bytes, not a `UIImage`: `NSItemProvider(object:)` leaves the type
    /// identifier to UIImage's own registration, and LinkPresentation
    /// didn't load it. An explicit `public.png` data representation is
    /// what the preview actually reads.
    let cardPNG: Data?

    init(title: String, link: URL, cardPNG: Data?) {
        self.title = title
        self.link = link
        self.cardPNG = cardPNG
        super.init()
    }

    private func pngProvider() -> NSItemProvider? {
        guard let cardPNG else { return nil }
        let provider = NSItemProvider()
        provider.registerDataRepresentation(for: .png) { completion in
            completion(cardPNG, nil)
            return nil
        }
        return provider
    }

    // The placeholder's type decides which activities the sheet offers, so
    // it's the URL: this share is a link that happens to carry a picture,
    // not a picture with a link stapled on.
    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        link
    }

    func activityViewController(_ controller: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        link
    }

    func activityViewController(_ controller: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = link
        metadata.url = link
        metadata.title = title
        // Both slots, deliberately. `imageProvider` is the large preview a
        // Messages bubble renders; `iconProvider` is the thumbnail the
        // share sheet's own header shows, and leaving it empty fell back
        // to a generic web compass — verified on the simulator, which is
        // also the cheapest proof the card reached the metadata at all.
        metadata.imageProvider = pngProvider()
        metadata.iconProvider = pngProvider()
        return metadata
    }
}

/// `UIActivityViewController` in a SwiftUI sheet — the only way to present
/// a share backed by `UIActivityItemSource`.
struct GameShareSheet: UIViewControllerRepresentable {
    let source: GameShareItemSource

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [source], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
