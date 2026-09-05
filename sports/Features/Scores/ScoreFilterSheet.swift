import SwiftUI

/// The Scores view-options sheet: grouping (by date / by conference),
/// season, and the ESPN-style slate filter. Consolidated here 2026-08-29
/// after the header chip row outgrew the screen; the header keeps only the
/// funnel chip (labeled with any non-default state) and the Live chip.
///
/// The slate list is the selected league's, because a filter can only
/// narrow what's on screen: college football offers Top 25 and every FBS
/// conference in the app's browsing order, then the FCS conferences in
/// their own section (picking one is what opts the slate into group 81).
/// The NFL offers the AFC and NFC and their eight divisions — and no
/// Top 25, because `/nfl/rankings` is a 404 and the poll doesn't exist.
///
/// Grouping and season apply in place; a conference tap selects and
/// dismisses, with the checkmark marking the active row.
struct ScoreFilterSheet: View {
    let league: League
    let current: ScoreFilter?
    let grouping: ScoresGrouping
    let seasonYear: Int?
    let seasons: [Int]
    let onSelect: (ScoreFilter?) -> Void
    let onSetGrouping: (ScoresGrouping) -> Void
    let onSelectSeason: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    /// What the selected league can narrow to. College football lists its
    /// FBS conferences (FCS gets its own section below); the NFL lists the
    /// AFC and NFC with their four divisions under each, which is how a
    /// fan reads the league.
    private var slateIds: [Int] {
        switch league {
        case .collegeFootball:
            Conference.orderedIds
        case .nfl:
            Conference.topLevelIds(in: .nfl)
                .flatMap { [$0] + Conference.children(of: $0, in: .nfl) }
        }
    }

    @ViewBuilder
    private func conferenceRow(_ id: Int) -> some View {
        let conference = ConferenceID(league, id)
        row(filter: .conference(conference),
            label: Conference.name(for: conference)) {
            ConferenceLogo(url: Conference.logoURL(for: conference))
                .frame(width: 24)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("View", selection: Binding(get: { grouping }, set: onSetGrouping)) {
                        Text("By date").tag(ScoresGrouping.date)
                        Text("By conference").tag(ScoresGrouping.conference)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.bgCard)
                    if let seasonYear, !seasons.isEmpty {
                        HStack {
                            Text("Season")
                                .font(.teamName)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            Picker("Season",
                                   selection: Binding(get: { seasonYear }, set: onSelectSeason)) {
                                ForEach(seasons, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(.textPrimary)
                        }
                        .listRowBackground(Color.bgCard)
                    }
                } header: {
                    heading("View")
                }
                Section {
                    row(filter: nil, label: "All games") {
                        Image(systemName: "football")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.textSecondary)
                            .frame(width: 24)
                    }
                    // No poll row for the NFL: `/nfl/rankings` is a 404,
                    // so a Top 25 filter would narrow to nothing forever.
                    if league == .collegeFootball {
                        row(filter: .top25, label: "Top 25") {
                            Image(systemName: "trophy")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.textSecondary)
                                .frame(width: 24)
                        }
                    }
                    ForEach(slateIds, id: \.self) { id in
                        conferenceRow(id)
                    }
                } header: {
                    heading(league == .nfl ? "Division" : "Conference")
                }
                // Its own section, below: FCS is opt-in (E8 scope (b)), and
                // picking one here is what puts group 81 on the slate. A
                // flat list would have made the default slate look like it
                // already covered 250 teams. The NFL has no second
                // division to opt into, so the section simply isn't there.
                if league == .collegeFootball {
                    Section {
                        ForEach(Conference.orderedIds(in: .fcs), id: \.self) { id in
                            conferenceRow(id)
                        }
                    } header: {
                        heading("FCS conference")
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(.teamNameEmphasis)
                        .foregroundStyle(.textPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Sentence-case section heading, the Rankings-hub language.
    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.teamNameEmphasis)
            .foregroundStyle(.textPrimary)
            .textCase(nil)
    }

    private func row(filter: ScoreFilter?, label: String,
                     @ViewBuilder mark: () -> some View) -> some View {
        Button {
            onSelect(filter)
            dismiss()
        } label: {
            HStack(spacing: Spacing.md) {
                mark()
                Text(label)
                    .font(filter == current ? .teamNameEmphasis : .teamName)
                    .foregroundStyle(.textPrimary)
                Spacer()
                if filter == current {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.bgCard)
        .accessibilityAddTraits(filter == current ? .isSelected : [])
    }
}

#Preview {
    Color.bgPrimary.sheet(isPresented: .constant(true)) {
        ScoreFilterSheet(league: .collegeFootball,
                         current: .conference(.cfb(8)), grouping: .date,
                         seasonYear: 2026,
                         seasons: Array(stride(from: 2026, through: 2014, by: -1)),
                         onSelect: { _ in }, onSetGrouping: { _ in },
                         onSelectSeason: { _ in })
    }
}
