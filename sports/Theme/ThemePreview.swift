import SwiftUI

/// Dev-only screen showing every theme token. Not reachable from the app UI;
/// view it via the previews below in both modes.
struct ThemePreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Colors").font(.sectionHeader).foregroundStyle(.textSecondary)
                    swatch("bgPrimary", .bgPrimary)
                    swatch("bgElevated", .bgElevated)
                    swatch("textPrimary", .textPrimary)
                    swatch("textSecondary", .textSecondary)
                    swatch("divider", .divider)
                    swatch("liveAccent", .liveAccent)
                }
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Type").font(.sectionHeader).foregroundStyle(.textSecondary)
                    Text("21 – 17 score").font(.score)
                    Text("21 – 17 scoreLive").font(.scoreLive).foregroundStyle(.liveAccent)
                    Text("21 – 17 scoreMuted").font(.scoreMuted).foregroundStyle(.textSecondary)
                    Text("Georgia teamName").font(.teamName)
                    Text("Georgia teamNameEmphasis").font(.teamNameEmphasis)
                    Text("3:30 PM · ESPN meta").font(.meta).foregroundStyle(.textSecondary)
                    Text("FINAL metaEmphasis").font(.metaEmphasis)
                    Text("TOP 25 sectionHeader").font(.sectionHeader)
                    Text("Week 5 chip").font(.chip)
                }
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Spacing").font(.sectionHeader).foregroundStyle(.textSecondary)
                    ForEach([("xs", Spacing.xs), ("sm", Spacing.sm), ("md", Spacing.md),
                             ("lg", Spacing.lg), ("xl", Spacing.xl)], id: \.0) { name, size in
                        HStack(spacing: Spacing.sm) {
                            Rectangle().fill(Color.textPrimary).frame(width: size, height: 12)
                            Text("\(name) \(Int(size))").font(.meta).foregroundStyle(.textSecondary)
                        }
                    }
                }
            }
            .foregroundStyle(.textPrimary)
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgPrimary)
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 44, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.divider))
            Text(name).font(.meta).foregroundStyle(.textSecondary)
        }
    }
}

#Preview("Light") {
    ThemePreview().preferredColorScheme(.light)
}

#Preview("Dark") {
    ThemePreview().preferredColorScheme(.dark)
}
