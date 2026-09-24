import SwiftUI

extension EnvironmentValues {
    /// The live dot's fill. Defaults to the red accent; overridable so
    /// design comparisons can render the row full-monochrome without a
    /// second row implementation (open question #2).
    @Entry var liveDotColor: Color = .liveAccent

    /// Whether the dot pulses. Static renders (ImageRenderer snapshots)
    /// turn this off so they don't capture the dot mid-dim.
    @Entry var liveDotPulses = true
}

/// The app's single splash of color: a small pulsing red dot marking a live game.
struct LiveDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.liveDotColor) private var color
    @Environment(\.liveDotPulses) private var pulses

    var body: some View {
        Group {
            // Reduce Motion (or a static render): the dot holds steady at
            // full opacity — and an `ImageRenderer` snapshot can't see a
            // UIKit layer anyway, so a static render must be the SwiftUI one.
            if reduceMotion || !pulses {
                Circle().fill(color)
            } else {
                PulsingDot(color: color)
            }
        }
        .frame(width: 6, height: 6)
        // Live status is spoken by the rows that contain the dot.
        .accessibilityHidden(true)
    }
}

/// The pulse, as a Core Animation layer animation rather than a SwiftUI
/// `repeatForever` (2026-09-24).
///
/// SwiftUI steps its own animations on the main thread, every frame, one
/// per dot — and a busy Saturday puts 20–60 live rows on the Scores screen,
/// a followed game counting twice. With ProMotion enabled that would be the
/// main thread ticking at 120Hz for as long as anything is live. A layer
/// animation runs in the render server and costs the app nothing per frame.
///
/// Every dot also shares one clock: the phase comes from media time, not
/// from when the dot appeared, so the slate pulses together instead of each
/// row starting its own beat whenever it scrolled in or a section opened.
///
/// The app's third UIKit exception (after the share sheet and the
/// `UIFontMetrics` bridge in `Theme.swift`), for the reason CLAUDE.md
/// allows one: a specific need SwiftUI can't meet.
private struct PulsingDot: UIViewRepresentable {
    let color: Color

    func makeUIView(context: Context) -> PulseLayerView {
        PulseLayerView()
    }

    func updateUIView(_ view: PulseLayerView, context: Context) {
        view.backgroundColor = UIColor(color)
    }
}

final class PulseLayerView: UIView {
    /// One full dim-and-back: 0.9s each way, as the SwiftUI pulse was.
    private static let halfPeriod: CFTimeInterval = 0.9
    private static let key = "live-pulse"

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }

    /// Core Animation drops a layer's animations when its view leaves the
    /// window, so the pulse is (re)attached on every arrival — a row
    /// scrolled back into view, a section reopened, the app foregrounded.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        layer.removeAnimation(forKey: Self.key)
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.25
        pulse.duration = Self.halfPeriod
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        // Start mid-cycle, wherever the shared clock is — this is what puts
        // every dot on the same beat.
        pulse.timeOffset = CACurrentMediaTime().truncatingRemainder(dividingBy: Self.halfPeriod * 2)
        pulse.isRemovedOnCompletion = false
        layer.add(pulse, forKey: Self.key)
    }
}

#Preview {
    LiveDot().padding()
}
