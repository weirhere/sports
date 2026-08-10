import SwiftUI

/// One conference's home: identity, follow, and its standings in the
/// provider's order (ESPN's encodes tiebreakers — never re-sorted here).
struct ConferencePage: View {
    let destination: ConferenceDestination

    @State private var standings: ConferenceStandings?
    @State private var isLoading = false
    @State private var lastError: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // Mirrors ConferenceStandingRow's column width so captions align with
    // the numbers beneath them.
    @ScaledMetric(relativeTo: .subheadline) private var recordWidth: CGFloat = 44

    private let client: any ScoresProviding = DataProvider.makeClient()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider().overlay(Color.divider)
                standingsSection
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle(destination.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            LogoImage(url: Conference.logoURL(for: destination.conferenceId))
                .frame(width: 64, height: 64)
                // Navy marks (Big Ten, ACC) vanish on black; the backing
                // disc is chrome, not color, so the budget holds.
                .background(Circle().fill(Color.logoBacking).padding(-8))
                .padding(8)
            Text(destination.name)
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            ConferenceFollowPill(conferenceId: destination.conferenceId)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    @ViewBuilder
    private var standingsSection: some View {
        if let entries = standings?.entries, !entries.isEmpty {
            Text("STANDINGS")
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            // At accessibility sizes the rows stack their records onto a
            // labeled line, so the column captions would caption nothing.
            if !dynamicTypeSize.isAccessibilitySize {
                columnHeader
            }
            ForEach(entries) { standing in
                NavigationLink(value: standing.team) {
                    ConferenceStandingRow(standing: standing)
                }
                .buttonStyle(.plain)
                if standing.id != entries.last?.id {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                }
            }
        } else if isLoading {
            ProgressView().padding(.vertical, Spacing.xl)
        } else if lastError != nil {
            VStack(spacing: Spacing.sm) {
                Text("Couldn't load standings.")
                    .font(.teamName)
                    .foregroundStyle(.textSecondary)
                Button("Retry") {
                    Task { await load(force: true) }
                }
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            }
            .padding(.vertical, Spacing.xl)
        } else {
            // ESPN's offseason standings can come back empty (Sun Belt did).
            Text("Standings TBA")
                .font(.teamName)
                .foregroundStyle(.textSecondary)
                .padding(.vertical, Spacing.xl)
        }
    }

    /// Column captions for the two record columns. Visual-only — each row
    /// speaks its records as a sentence, so VO skips this line.
    private var columnHeader: some View {
        HStack(spacing: Spacing.md) {
            Text("TEAM")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CONF")
                .frame(minWidth: recordWidth, alignment: .trailing)
            Text("OVR")
                .frame(minWidth: recordWidth, alignment: .trailing)
        }
        .font(.meta)
        .foregroundStyle(.textSecondary)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xs)
        .accessibilityHidden(true)
    }

    private func load(force: Bool = false) async {
        guard standings == nil || force else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await client.conferenceStandings()
            standings = all.first { $0.id == destination.conferenceId }
                ?? ConferenceStandings(id: destination.conferenceId,
                                       name: destination.name, entries: [])
            lastError = nil
        } catch {
            lastError = "Couldn't load standings."
        }
    }
}
