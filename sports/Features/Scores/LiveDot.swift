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

    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(dimmed ? 0.25 : 1)
            .onAppear {
                // Reduce Motion (or a static render): the dot holds
                // steady at full opacity.
                guard !reduceMotion, pulses else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
            // Live status is spoken by the rows that contain the dot.
            .accessibilityHidden(true)
    }
}

#Preview {
    LiveDot().padding()
}
