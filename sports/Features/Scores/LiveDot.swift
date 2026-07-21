import SwiftUI

/// The app's single splash of color: a small pulsing red dot marking a live game.
struct LiveDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(Color.liveAccent)
            .frame(width: 6, height: 6)
            .opacity(dimmed ? 0.25 : 1)
            .onAppear {
                // Reduce Motion: the dot holds steady at full opacity.
                guard !reduceMotion else { return }
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
