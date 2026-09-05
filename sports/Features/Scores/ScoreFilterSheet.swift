import SwiftUI

/// The Scores view-options sheet: season, and the ESPN-style slate filter.
/// Consolidated here 2026-08-29 after the header chip row outgrew the
/// screen; the header keeps only the funnel chip (labeled with any
/// non-default state) and the Live chip.
///
/// The grouping control came back out on 2026-09-05, when the day became
/// the screen's axis and the leagues became its sections — there is one
/// shape now, and the section headers on screen already say what it is.
///
/// The slate list spans every league, because the screen does: college
/// football offers Top 25 and every FBS conference in the app's browsing
/// order, then the FCS conferences in their own section (picking one is
/// what opts the slate into group 81). The NFL offers the AFC and NFC and
/// their eight divisions — and no Top 25, because `/nfl/rankings` is a 404
/// and the poll doesn't exist.
///
/// Season applies in place; a conference tap selects and dismisses, with
/// the checkmark marking the active row.
struct ScoreFilterSheet: View {
    let current: ScoreFilter?
    let seasonYear: Int?
    let seasons: [Int]
    let onSelect: (ScoreFilter?) -> Void
    let onSelectSeason: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    /// What a league can narrow to. College football lists its FBS
    /// conferences (FCS gets its own section below); the NFL lists the AFC
    /// and NFC with their four divisions under each, which is how a fan
    /// reads the league.
    private func slateIds(in league: League) -> [Int] {
        switch league {
        case .collegeFootball:
            Conference.orderedIds
        case .nfl:
            Conference.topLevelIds(in: .nfl)
                .flatMap { [$0] + Conference.children(of: $0, in: .nfl) }
        }
    }

    @ViewBuilder
    private func conferenceRow(_ id: Int, in league: League) -> some View {
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
                if let seasonYear, !seasons.isEmpty {
                    Section {
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
                    } header: {
                        heading("View")
                    }
                }
                Section {
                    row(filter: nil, label: "All games") {
                        Image(systemName: "football")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.textSecondary)
                            .frame(width: 24)
                    }
                    // Top 25 is a college-football question — the NFL has
                    // no poll (`/nfl/rankings` is a 404) — so selecting it
                    // hides the NFL section rather than emptying it.
                    row(filter: .top25, label: "Top 25") {
                        Image(systemName: "trophy")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.textSecondary)
                            .frame(width: 24)
                    }
                } header: {
                    heading("Slate")
                }
                // One section per league, in the same order the accordions
                // stack on screen — a filter narrows to a conference, and
                // which league's conference it is has to be obvious.
                ForEach(League.allCases) { league in
                    Section {
                        ForEach(slateIds(in: league), id: \.self) { id in
                            conferenceRow(id, in: league)
                        }
                    } header: {
                        heading(league.displayName)
                    }
                }
                // Its own section, below: FCS is opt-in (E8 scope (b)), and
                // picking one here is what puts group 81 on the slate. A
                // flat list would have made the default slate look like it
                // already covered 250 teams.
                Section {
                    ForEach(Conference.orderedIds(in: .fcs), id: \.self) { id in
                        conferenceRow(id, in: .collegeFootball)
                    }
                } header: {
                    heading("FCS conference")
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
        ScoreFilterSheet(current: .conference(.cfb(8)),
                         seasonYear: 2026,
                         seasons: Array(stride(from: 2026, through: 2014, by: -1)),
                         onSelect: { _ in },
                         onSelectSeason: { _ in })
    }
}
