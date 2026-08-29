import SwiftUI

/// The Scores view-options sheet: grouping (by date / by conference),
/// season, and the ESPN-style slate filter — all games, Top 25, then every
/// FBS conference in the app's browsing order. Consolidated here 2026-08-29
/// after the header chip row outgrew the screen; the header keeps only the
/// funnel chip (labeled with any non-default state) and the Live chip.
///
/// Grouping and season apply in place; a conference tap selects and
/// dismisses, with the checkmark marking the active row.
struct ScoreFilterSheet: View {
    let current: ScoreFilter?
    let grouping: ScoresGrouping
    let seasonYear: Int?
    let seasons: [Int]
    let onSelect: (ScoreFilter?) -> Void
    let onSetGrouping: (ScoresGrouping) -> Void
    let onSelectSeason: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("View", selection: Binding(get: { grouping }, set: onSetGrouping)) {
                        Text("By date").tag(ScoresGrouping.date)
                        Text("By conference").tag(ScoresGrouping.conference)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.bgPrimary)
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
                        .listRowBackground(Color.bgPrimary)
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
                    row(filter: .top25, label: "Top 25") {
                        Image(systemName: "trophy")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.textSecondary)
                            .frame(width: 24)
                    }
                    ForEach(Conference.orderedIds, id: \.self) { id in
                        row(filter: .conference(id), label: Conference.name(for: id)) {
                            ConferenceLogo(url: Conference.logoURL(for: id))
                                .frame(width: 24)
                        }
                    }
                } header: {
                    heading("Conference")
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
        .listRowBackground(Color.bgPrimary)
        .accessibilityAddTraits(filter == current ? .isSelected : [])
    }
}

#Preview {
    Color.bgPrimary.sheet(isPresented: .constant(true)) {
        ScoreFilterSheet(current: .conference(8), grouping: .date,
                         seasonYear: 2026,
                         seasons: Array(stride(from: 2026, through: 2014, by: -1)),
                         onSelect: { _ in }, onSetGrouping: { _ in },
                         onSelectSeason: { _ in })
    }
}
