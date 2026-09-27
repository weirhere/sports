import SwiftUI

/// The Trades tab's control row: "Signings & trades" or "All" (the brief's
/// D7). The Games tab's toggle chips, so the pane's controls read as the
/// rest of the app's do — but a pair where one is always on, since the tab
/// has two views and no third.
///
/// No season chip beside them: ESPN pages the wire by calendar year, not
/// season, so there is no season to pick (see `RosterMovesFeed`).
struct TradesFilterRow: View {
    let selection: RosterMove.Filter
    let onSelect: (RosterMove.Filter) -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            SlateToggleChip(title: "Signings & trades", isOn: selection == .signingsAndTrades,
                            hint: "Hides waivers, releases and practice-squad moves") {
                onSelect(.signingsAndTrades)
            }
            SlateToggleChip(title: "All", isOn: selection == .all,
                            hint: "Shows every roster move") {
                onSelect(.all)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    TradesFilterRow(selection: .signingsAndTrades, onSelect: { _ in })
        .padding()
        .background(Color.bgRecessed)
}
