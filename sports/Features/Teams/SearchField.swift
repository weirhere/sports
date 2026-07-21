import SwiftUI

/// The pinned team-search field Teams and Onboarding share. Custom rather
/// than `.searchable` because the nav-bar drawer clips the system field's
/// shadow at the drawer edge; owning the field lets the shadow bleed as far
/// as it reaches. `.isSearchField` keeps it discoverable as a search field
/// for VoiceOver and UI tests.
struct SearchField: View {
    @Binding var text: String
    var prompt: String

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
                .accessibilityAddTraits(.isSearchField)
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
