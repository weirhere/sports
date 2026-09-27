import SwiftUI

/// The Gamecast's "this just happened" marker: a map pin with the team's
/// logo, its point on the spot (2026-09-27). The field puts it over the
/// ball, the court and rink over the newest shot, and nothing else on
/// the card highlights (D7). Shared so the three can't drift.
struct LogoPin: View {
    let logoURL: URL?

    static let width: CGFloat = 26
    static let height: CGFloat = 33

    var body: some View {
        ZStack(alignment: .top) {
            PinShape()
                .fill(Color.bgCard)
                .overlay(PinShape().stroke(Color.divider, lineWidth: 1))
            LogoImage(url: logoURL, placeholder: nil)
                .frame(width: 17, height: 17)
                .padding(.top, 4.5)
        }
        .frame(width: Self.width, height: Self.height)
    }
}

/// A disc for the logo with a point beneath it.
private struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        let center = CGPoint(x: rect.midX, y: radius)
        var path = Path()
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(145), endAngle: .degrees(35), clockwise: false)
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
