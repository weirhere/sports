import SwiftUI

/// The Trophies tab's card: one row per trophy, the count on the right and
/// the years beneath it.
///
/// The table language the team-page cards already speak — a `CardHeader`
/// over hairline-divided rows, the count in monospaced digits so a column
/// of them lines up. What it deliberately is **not** is a grid of trophy
/// artwork: the app has no such assets, the color budget would not pay for
/// them, and the answer a fan wants here is a number and a list of years.
///
/// Rows are **not links**, for `RosterRow`'s reason and one of their own:
/// there is no trophy page anywhere in the app, and a row that spans four
/// seasons has no single game to open — a chevron would promise one.
struct TeamTrophiesCard: View {
    let trophyCase: TrophyCase

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: "Trophies")
            ForEach(Array(trophyCase.groups.enumerated()), id: \.element.id) { index, group in
                if index > 0 {
                    Divider().overlay(Color.divider)
                        .padding(.leading, Spacing.lg)
                }
                row(group)
            }
            if let footnote {
                Text(footnote)
                    .font(.rowMeta)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)
                    // Spoken once, at the foot of the card, rather than
                    // repeated into every row's sentence.
                    .accessibilityLabel(footnoteAccessibilityLabel ?? footnote)
            }
        }
        .padding(.bottom, footnote == nil ? Spacing.xs : 0)
    }

    private func row(_ group: TrophyGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .font(.rowNameEmphasis)
                    .foregroundStyle(.textPrimary)
                Text(group.years.map(String.init).joined(separator: ", "))
                    .font(.rowMeta)
                    .foregroundStyle(.textSecondary)
                    .monospacedDigit()
            }
            Spacer(minLength: Spacing.sm)
            Text(group.count.formatted())
                .font(.rowNameEmphasis)
                .monospacedDigit()
                .foregroundStyle(.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(group))
    }

    /// "3 SEC Championships, 2025, 2022 and 2017" — the count leads,
    /// because it is the answer, and the years are read as a list rather
    /// than as a run of digits.
    private func label(_ group: TrophyGroup) -> String {
        let years = group.years.map(String.init)
        let list: String
        switch years.count {
        case 0: list = ""
        case 1: list = years[0]
        default: list = years.dropLast().joined(separator: ", ") + " and " + years[years.count - 1]
        }
        return "\(group.count) \(group.title), \(list)"
    }

    /// Said out loud, never implied. A shelf that only knows the seasons
    /// ESPN can reach has to say so — an eighteen-time champion showing
    /// six with no caption is the omission the whole feature is built
    /// against. Nil when every row is all-time, which is the only case
    /// where silence is the truth.
    private var footnote: String? {
        guard let floor = trophyCase.coverageFloor else { return nil }
        let scoped = trophyCase.groups.filter { $0.coverage != .allTime }
        let allScoped = scoped.count == trophyCase.groups.count
        return allScoped
            ? "Since \(floor)"
            : "\(scoped.map(\.title).formatted(.list(type: .and))) since \(floor)"
    }

    private var footnoteAccessibilityLabel: String? {
        footnote.map { "Coverage: \($0)" }
    }
}

#Preview {
    let cfp = TrophyKind(singular: "National Championship",
                         plural: "National Championships", tier: .league)
    let sec = TrophyKind(singular: "SEC Championship",
                         plural: "SEC Championships", tier: .conference)
    return VStack(spacing: Spacing.sm) {
        TeamTrophiesCard(trophyCase: TrophyCase(groups: [
            TrophyGroup(kind: cfp, years: [2022, 2021], coverage: .allTime),
            TrophyGroup(kind: sec, years: [2025, 2022, 2017], coverage: .since(2014)),
        ]))
        .cardSurface()
        TeamTrophiesCard(trophyCase: TrophyCase(groups: [
            TrophyGroup(kind: sec, years: [2025], coverage: .since(2014)),
        ]))
        .cardSurface()
    }
    .padding(Spacing.sm)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.bgRecessed)
}
