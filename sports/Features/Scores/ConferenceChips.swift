import SwiftUI

/// The Live filter chip plus one jump chip per section. Jump chips scroll-
/// anchor to their section (expanding it if collapsed) — they never filter.
struct ConferenceChips: View {
    let sections: [GameSection]
    let liveOnly: Bool
    let hasLiveGames: Bool
    let onToggleLive: () -> Void
    let onJump: (GameSection) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                if hasLiveGames || liveOnly {
                    liveChip
                }
                ForEach(sections) { section in
                    Button {
                        onJump(section)
                    } label: {
                        chipLabel(section.title, selected: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
        }
    }

    private var liveChip: some View {
        Button(action: onToggleLive) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.liveAccent)
                    .frame(width: 6, height: 6)
                Text("Live")
                    .font(.chip)
            }
            .foregroundStyle(liveOnly ? Color.bgPrimary : Color.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(liveOnly ? Color.textPrimary : Color.bgElevated)
            )
        }
        .buttonStyle(.plain)
    }

    private func chipLabel(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.chip)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.bgElevated))
    }
}
