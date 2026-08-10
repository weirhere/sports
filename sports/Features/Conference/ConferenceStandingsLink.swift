import SwiftUI

/// The trailing standings affordance on a conference accordion header —
/// sits beside the header's toggle button, never inside it, so the
/// expand/collapse surface keeps its whole-width promise. Closure-driven
/// (the owning screen appends to its navigation path) so the header's
/// context menu and VoiceOver action can share the exact same push.
struct ConferenceStandingsLink: View {
    let conferenceName: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            Image(systemName: "list.number")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(conferenceName) standings")
    }
}
