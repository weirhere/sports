import SwiftUI

/// Placeholder section stack shown while the first load is in flight.
struct SkeletonRows: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { section in
                HStack {
                    bar(width: 90, height: 13)
                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: 6) {
                            teamBar
                            teamBar
                        }
                        Spacer()
                        bar(width: 56, height: 12)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, 8)
                }
                Divider().overlay(Color.divider)
            }
        }
        .opacity(pulsing ? 0.45 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }

    @State private var pulsing = false

    private var teamBar: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.bgElevated).frame(width: 20, height: 20)
            bar(width: 120, height: 12)
        }
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        Capsule().fill(Color.bgElevated).frame(width: width, height: height)
    }
}

#Preview {
    SkeletonRows().background(Color.bgCard)
}
