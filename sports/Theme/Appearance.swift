import UIKit

/// The Settings sheet's appearance choice (2026-09-25). `system` follows the
/// iPhone's own Light/Dark setting and is the default; the other two pin the
/// app. Widgets and Live Activities render outside the app and keep following
/// the system.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    private var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Pins every window in the app to this appearance, or releases them.
    ///
    /// On the window rather than through `preferredColorScheme`, because
    /// going from Dark back to `nil` left the open Settings sheet dark while
    /// the screen behind it turned light (iOS 18.3, 2026-09-25). A window's
    /// `overrideUserInterfaceStyle` reaches everything it presents, sheets
    /// and the share sheet included, and `.unspecified` really does hand
    /// the choice back to iOS.
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
}
