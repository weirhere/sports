import SwiftUI

/// The Overview tab's record breakdown: conference and overall W-L as two
/// quiet metric rows. Strings come straight from the standings payload (or
/// the schedule's derived record for past seasons) — never recomputed here.
struct TeamRecordCard: View {
    /// Which league's vocabulary the in-group row uses. Every league that
    /// carries an in-group record calls it a conference record; the NHL
    /// carries none at all, so the row is simply absent there.
    var league: League = .collegeFootball
    /// Nil hides the row — past seasons and no-conference teams show
    /// overall only.
    let conferenceRecord: String?
    let overallRecord: String?

    /// Preseason gate, `MatchupStandings.hasContent`'s rule: the card says
    /// something once the OVERALL line does — a September team legitimately
    /// sits 0-0 in conference while its overall record already talks.
    static func hasContent(conferenceRecord: String?, overallRecord: String?) -> Bool {
        guard let overallRecord else { return false }
        // "0-0" in football, "0-0-0" in hockey — a season that hasn't
        // started has nothing to say either way.
        return overallRecord != "0-0" && overallRecord != "0-0-0"
    }

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: "Record")
            if let conferenceRecord {
                row(inGroupLabel, conferenceRecord)
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

    /// The long form of the league's in-group standings column, for a
    /// card row rather than a table caption.
    private var inGroupLabel: String {
        league.standingsColumns
            .first { $0.field == .inGroupRecord }
            .map { $0.spoken.replacingOccurrences(of: "in ", with: "").capitalized }
            ?? "Conference"
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
