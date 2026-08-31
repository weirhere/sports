import SwiftUI

/// The Overview tab's record breakdown: conference and overall W-L as two
/// quiet metric rows. Strings come straight from the standings payload (or
/// the schedule's derived record for past seasons) — never recomputed here.
struct TeamRecordCard: View {
    /// Nil hides the row — past seasons and no-conference teams show
    /// overall only.
    let conferenceRecord: String?
    let overallRecord: String?

    /// Preseason gate, `MatchupStandings.hasContent`'s rule: the card says
    /// something once the OVERALL line does — a September team legitimately
    /// sits 0-0 in conference while its overall record already talks.
    static func hasContent(conferenceRecord: String?, overallRecord: String?) -> Bool {
        overallRecord != nil && overallRecord != "0-0"
    }

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: "Record")
            if let conferenceRecord {
                row("Conference", conferenceRecord)
                if overallRecord != nil {
                    Divider().overlay(Color.divider)
                        .padding(.leading, Spacing.lg)
                }
            }
            if let overallRecord {
                row("Overall", overallRecord)
            }
        }
        .padding(.bottom, Spacing.xs)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(label)
                .font(.rowName)
                .foregroundStyle(.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(.rowNameEmphasis)
                .monospacedDigit()
                .foregroundStyle(.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) record \(value)")
    }
}
