import SwiftUI

/// A pane's control row on an entity page: the season chip leading, the
/// pane's own controls after it (Andy, 2026-09-27). The season sits with
/// the cards it scopes rather than on the toolbar row, and leads so it
/// holds one spot as the tabs change what follows it.
///
/// A Games tab can carry four chips — season, Weeks, Date and the team
/// filter — which is right at the width of a phone at the default text
/// size and past it at larger ones. Where the row doesn't fit, the season
/// takes a line of its own above the rest rather than clipping a chip.
struct SeasonControlRow<Controls: View>: View {
    let season: SeasonMenuChip
    @ViewBuilder var controls: Controls

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.sm) {
                season
                controls
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 0) {
                season
                HStack(spacing: Spacing.sm) {
                    controls
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

#Preview {
    SeasonControlRow(season: SeasonMenuChip(current: 2026, seasons: [2026, 2025],
                                            onSelect: { _ in })) {
        SlateToggleChip(title: "Weeks", isOn: true, onToggle: {})
        SlateToggleChip(title: "Date", isOn: false, onToggle: {})
    }
    .padding()
    .background(Color.bgRecessed)
}
