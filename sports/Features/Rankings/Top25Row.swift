import SwiftUI

/// The poll's row in the Rankings list — the same shape as a conference
/// row, leading the list so the tab's #1 answer stays one obvious tap away.
struct Top25Row: View {
    /// The FBS polls, filtered and in picker order; pushed on to PollScreen.
    let polls: [Poll]

    var body: some View {
        NavigationLink {
            PollScreen(polls: polls)
        } label: {
            HStack(spacing: Spacing.md) {
                // Same trophy and footprint as the Scores section header,
                // so the mark column lines up with the conference logos.
                Image(systemName: "trophy.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.textSecondary)
                    .frame(width: 18, height: 18)
                Text("Top 25")
                    .font(.teamName)
                    .foregroundStyle(.textPrimary)
                if let teaser {
                    Text(teaser)
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rankings-top25-row")
    }

    /// "#1 Ohio State" from the first displayed poll (AP when present).
    /// The row doesn't track the picker choice — it's a teaser, not the poll.
    private var teaser: String? {
        guard let top = polls.first?.ranks.first else { return nil }
        return "#1 \(top.team.location)"
    }

    var accessibilitySummary: String {
        guard let top = polls.first?.ranks.first else { return "Top 25" }
        return "Top 25, number 1 \(top.team.location)"
    }
}
