import SwiftUI

/// The app's single splash of color: a small pulsing red dot marking a live game.
struct LiveDot: View {
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(Color.liveAccent)
            .frame(width: 6, height: 6)
            .opacity(dimmed ? 0.25 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
    }
}

#Preview {
    LiveDot().padding()
}
