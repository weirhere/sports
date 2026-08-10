import SwiftUI

/// The pinned team-search field Teams and Onboarding share. Custom rather
/// than `.searchable` because the nav-bar drawer clips the system field's
/// shadow at the drawer edge; owning the field lets the shadow bleed as far
/// as it reaches. `.isSearchField` keeps it discoverable as a search field
/// for VoiceOver and UI tests.
struct SearchField: View {
    @Binding var text: String
    var prompt: String
    /// The app-wide search cover grabs the keyboard on open; the pinned
    /// Teams/Onboarding fields don't (their screens are for browsing first).
    var focusOnAppear = false
    /// Distinguishes the cover's field from the Teams tab's pinned one when
    /// both exist — UI tests can't rely on `searchFields.firstMatch` then.
    var identifier = ""

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.textSecondary)
            TextField(prompt, text: $text)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($isFocused)
                .accessibilityAddTraits(.isSearchField)
                .accessibilityIdentifier(identifier)
                .task {
                    guard focusOnAppear else { return }
                    // The presentation transition steals first responder; a
                    // focus set mid-transition is silently dropped, so keep
                    // asking until it sticks (or the user moved on).
                    for _ in 0..<4 {
                        try? await Task.sleep(for: .milliseconds(300))
                        if isFocused || !text.isEmpty { return }
                        isFocused = true
                    }
                }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.bgPrimary)
                // A touch stronger than the card shadow: the field floats
                // over scrolling content, so it earns more lift.
                .shadow(color: .black.opacity(0.08), radius: 10, y: 2)
        )
    }
}

#Preview {
    @Previewable @State var text = ""
    VStack {
        SearchField(text: $text, prompt: "Find a team")
            .padding(Spacing.sm)
        Spacer()
    }
    .background(Color.bgRecessed)
}
