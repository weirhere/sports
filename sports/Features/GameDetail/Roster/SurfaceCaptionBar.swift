import SwiftUI

/// A team's bar on the court or the rink: its 32pt logo and name on the
/// heading paint, 48pt tall, with a hairline in the surface's own paint
/// above it (the Figma sheet "↳ Roster variants", 2026-10-27). The court
/// has one, for the home side under the floor; the rink has one at each
/// end, the away side's between the title and the ice. Football, whose
/// strips choose a unit, has a strip at each end instead.
struct SurfaceCaptionBar: View {
    let team: Team
    let league: League

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 48
    @ScaledMetric(relativeTo: .callout) private var logoSize: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(SurfaceColors.base(for: league))
                .frame(height: 1)
            HStack(spacing: Spacing.sm) {
                LogoImage(url: team.logoURL)
                    .frame(width: logoSize, height: logoSize)
                Text(team.abbreviation ?? team.location)
                    .font(.surfaceCaption)
                    .foregroundStyle(SurfaceColors.ink(for: league).text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.sm + Spacing.md)
            .frame(maxHeight: .infinity)
        }
        .frame(height: height)
        .accessibilityElement(children: .combine)
    }
}
