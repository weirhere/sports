import SwiftUI

/// The game page's header once it has scrolled under the bar: both marks
/// at 22pt with the score between them, in the nav bar's principal slot
/// (Andy's Paper pass, 2026-10-02). The full header's facts, one line.
struct CompactGameHeader: View {
    typealias Side = (team: Team, score: Int?, record: String?, winner: Bool?)

    /// What sits between the marks.
    enum Middle: Equatable {
        /// Before kickoff: the time takes the score's slot, as it does in
        /// the full header.
        case kickoff(String)
        /// A played game. A live one shows its clock between the numbers;
        /// a final shows the dash, and VoiceOver reads its status.
        case score(away: Int, home: Int, status: String, isLive: Bool)
        /// No score and no kickoff ("Postponed").
        case status(String)
    }

    let away: Side
    let home: Side
    let middle: Middle
    let possessionTeamId: String?
    let glyph: String

    private static let logoSize: CGFloat = 22

    var body: some View {
        HStack(spacing: Spacing.md) {
            mark(away.team, outside: .leading)
            center
            mark(home.team, outside: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    @ViewBuilder
    private var center: some View {
        switch middle {
        case .kickoff(let time):
            Text(time)
                .font(Self.scoreFont)
                .foregroundStyle(.textPrimary)
        case let .score(awayScore, homeScore, status, isLive):
            HStack(spacing: Spacing.xs) {
                Text("\(awayScore)")
                    .font(Self.scoreFont)
                    .frame(minWidth: 24)
                Group {
                    if isLive {
                        // A fixed-width slot, so the numbers hold still
                        // as the clock text changes length.
                        Text(status)
                            .foregroundStyle(.textSecondary)
                            .frame(minWidth: 90)
                    } else {
                        Text("–")
                    }
                }
                .font(Self.statusFont)
                .lineLimit(1)
                Text("\(homeScore)")
                    .font(Self.scoreFont)
                    .frame(minWidth: 24)
            }
            .foregroundStyle(.textPrimary)
        case .status(let status):
            Text(status)
                .font(Self.statusFont)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
    }

    /// The bar's own sizes rather than Dynamic Type's, like every other
    /// principal title in the app: the bar's height doesn't grow with them.
    private static let scoreFont = Font.system(size: 17, weight: .semibold).monospacedDigit()
    private static let statusFont = Font.system(size: 12, weight: .semibold).monospacedDigit()

    /// A team's mark, with the possession glyph hung 8pt off its outer
    /// edge — the full header's placement, at the bar's scale.
    private func mark(_ team: Team, outside edge: HorizontalEdge) -> some View {
        LogoImage(url: team.logoURL)
            .frame(width: Self.logoSize, height: Self.logoSize)
            .overlay(alignment: edge == .leading ? .leading : .trailing) {
                if possessionTeamId != nil, possessionTeamId == team.id {
                    Image(systemName: glyph)
                        .font(.system(size: 9))
                        .foregroundStyle(.textSecondary)
                        .padding(edge == .leading ? .trailing : .leading, Spacing.sm)
                        .fixedSize()
                        .frame(width: 0, alignment: edge == .leading ? .trailing : .leading)
                }
            }
    }

    private var spoken: String {
        let ball: (Team) -> String = { team in
            possessionTeamId != nil && possessionTeamId == team.id ? ", has the ball" : ""
        }
        switch middle {
        case .kickoff(let time):
            return "\(away.team.location) at \(home.team.location), \(time)"
        case let .score(awayScore, homeScore, status, _):
            let sides = "\(away.team.location) \(awayScore)\(ball(away.team)), "
                + "\(home.team.location) \(homeScore)\(ball(home.team))"
            return "\(sides), \(status)"
        case .status(let status):
            return "\(away.team.location) at \(home.team.location), \(status)"
        }
    }
}
