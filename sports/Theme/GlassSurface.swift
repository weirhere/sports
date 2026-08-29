import SwiftUI

/// Liquid Glass where the OS offers it (iOS 26+), the flat monochrome
/// surface everywhere else — one seam so the 18.0 floor keeps today's
/// exact chrome. Glass is chrome-only by design: the floating control
/// layer (header cluster, strip chips, hero controls) gets it, content
/// cards stay ink on paper, and glass never stacks on glass (the group
/// capsule is glass, the pills inside it are not).
extension View {
    /// A resting glass capsule — the group/container surface.
    @ViewBuilder
    func glassCapsule(fallback: Color) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: Capsule())
        } else {
            background(Capsule().fill(fallback))
        }
    }

    /// A tappable glass capsule; `tint` carries a selected state's ink.
    @ViewBuilder
    func glassCapsuleInteractive(tint: Color? = nil, fallback: Color) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                glassEffect(.regular.tint(tint).interactive(), in: Capsule())
            } else {
                glassEffect(.regular.interactive(), in: Capsule())
            }
        } else {
            background(Capsule().fill(fallback))
        }
    }
}
