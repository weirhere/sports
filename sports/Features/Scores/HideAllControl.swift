import SwiftUI

/// The boundary between the sections that are yours — Following, and every
/// conference/league/poll you follow — and the rest of the day's slate
/// below them (FotMob parity, Andy 2026-09-22). One tap collapses that
/// whole remaining stack to this one line, or brings it back; it never
/// touches Following, a followed table, or any accordion's own expanded
/// state, which is what makes it safe to leave on across days.
///
/// Only ever placed where there's an actual boundary to draw — see
/// `ScoresScreen.scoresRows(for:hideOthers:)`, which omits it entirely when
/// you follow nobody or when what you follow already covers the whole day.
struct HideAllControl: View {
    /// The sections this control hides, in slate order.
    let others: [GameSection]
    let isHidden: Bool
    /// Whether the caption naming what's hidden is shown. Separate from
    /// `isHidden` because the label flips the instant Hide all is tapped,
    /// but the caption waits for the sections to be covered: shown any
    /// earlier, it pushes them 30pt down just before they sweep away.
    var showsCaption: Bool? = nil
    /// Draws the caption early, in the spot it will take but with no
    /// height, while the hidden sections are still fading beneath it. With
    /// no height it can't push them, so the caption's fade overlaps theirs
    /// instead of adding a beat after it; once they're gone it claims its
    /// height in place.
    var showsEarlyCaption = false
    let onToggle: () -> Void

    var body: some View {
        // The caption sits 12pt under the capsule (Andy, 2026-09-26): at 4
        // it read as part of the button rather than a line about the slate.
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: Spacing.sm) {
                    Text(isHidden ? "Show all" : "Hide all")
                        .font(.chipEmphasis)
                    Image(systemName: isHidden ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.textPrimary)
                // The label flips; it never crossfades. Caught up in the
                // sections' motion, "Hide all" and "Show all" overlapped
                // for a few frames.
                .transaction { $0.animation = nil }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm + 2)
                .background(Capsule().fill(Color.bgInset))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isHidden ? "Show all sections" : "Hide all sections")
            .accessibilityValue(isHidden ? Self.summary(of: others) : "")
            .accessibilityIdentifier("scores-hide-all-control")
            // Named so a hidden stack never reads as gone for good — what's
            // behind it is the whole reason this isn't just an empty tap
            // target (FotMob's "22 other competitions play today"). The
            // button's own accessibilityValue already says it, so this
            // stays out of VoiceOver rather than repeating it.
            let laidOut = showsCaption ?? isHidden
            if laidOut || showsEarlyCaption {
                caption
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.md)
                    // Drawn early, it takes no height: it overflows into
                    // the spot it will occupy without pushing the fading
                    // sections, then claims that height in place once
                    // they're gone — one view throughout, so no jump.
                    .frame(height: laidOut ? nil : 0, alignment: .top)
            }
        }
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity)
    }

    private var caption: some View {
        Text(Self.summary(of: others))
            .font(.meta)
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
            .accessibilityHidden(true)
            .transition(.opacity)
    }

    /// "Big Ten, SEC and 2 other leagues, conferences or divisions play
    /// today" (Andy, 2026-09-25). The first two sections are named, the
    /// rest counted. A catch-all "Other" section is never one of the two
    /// named — "Other" says nothing — but it still counts.
    static func summary(of sections: [GameSection]) -> String {
        let named = sections
            .filter { !$0.id.hasPrefix(GameSection.otherPrefix) }
            .prefix(2)
            .map(\.title)
        let rest = sections.count - named.count
        var parts = named
        if rest > 0 {
            parts.append(rest == 1
                ? "1 other league, conference or division"
                : "\(rest) other leagues, conferences or divisions")
        }
        let list = switch parts.count {
        case 0: ""
        case 1: parts[0]
        default: parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
        }
        return list + (sections.count == 1 ? " plays today" : " play today")
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        let others = ["Big Ten", "SEC", "ACC", "Big 12"].map {
            GameSection(id: "conf-\($0)", title: $0, games: [])
        }
        HideAllControl(others: others, isHidden: false, onToggle: {})
        HideAllControl(others: others, isHidden: true, onToggle: {})
    }
    .padding()
    .background(Color.bgRecessed)
}
