import SwiftUI

/// The Profile tab: the career in big numbers, then the record lines and
/// the bio, each skipping whatever ESPN didn't send.
struct CoachProfilePane: View {
    let profile: CoachProfile
    let league: League

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if let tiles = headlineTiles {
                StatTilesCard(title: "Head coaching career", tiles: tiles)
            }
            if !recordRows.isEmpty {
                LabeledValueCard(title: "Record", rows: recordRows)
            }
            if !bioRows.isEmpty {
                LabeledValueCard(title: "Profile", rows: bioRows)
            }
        }
    }

    /// Seasons, wins, win % and — where ESPN splits it out — playoff wins.
    private var headlineTiles: [StatTilesCard.Tile]? {
        guard let total = profile.records.first(where: { $0.kind == .total })
                ?? profile.records.first else { return nil }
        var tiles: [StatTilesCard.Tile] = []
        if !profile.seasons.isEmpty {
            tiles.append(.init(label: "SEASONS", spokenLabel: "Seasons",
                               value: String(Set(profile.seasons.map(\.year)).count)))
        }
        tiles.append(.init(label: "W-L", spokenLabel: "Record", value: total.summary))
        if let pct = total.winPercentText {
            tiles.append(.init(label: "PCT", spokenLabel: "Win percentage", value: pct))
        }
        if let post = profile.records.first(where: { $0.kind == .postseason }) {
            tiles.append(.init(label: "PLAYOFFS", spokenLabel: "Playoff record", value: post.summary))
        }
        return tiles
    }

    private var recordRows: [LabeledValueCard.Row] {
        profile.records.map { record in
            let value = [record.summary, record.winPercentText].compactMap { $0 }.joined(separator: " · ")
            return LabeledValueCard.Row(label: record.kind.title, value: value)
        }
    }

    private var bioRows: [LabeledValueCard.Row] {
        // The role leads, as a player's position does in theirs: ESPN only
        // lists head coaches, so it's the one row every coach has.
        var rows: [LabeledValueCard.Row] = [.init(label: "Position", value: "Head coach")]
        if let age = profile.age() { rows.append(.init(label: "Age", value: String(age))) }
        if let place = profile.birthPlace { rows.append(.init(label: "Born", value: place)) }
        if let college = profile.college { rows.append(.init(label: "College", value: college)) }
        if let first = profile.seasons.last?.year {
            rows.append(.init(label: "First season", value: league.seasonLabel(first)))
        }
        return rows
    }
}
