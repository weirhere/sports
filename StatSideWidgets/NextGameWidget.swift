import SwiftUI
import WidgetKit

struct NextGameWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppGroup.widgetKind, provider: NextGameProvider()) { entry in
            NextGameWidgetView(entry: entry)
                .containerBackground(Color.bgPrimary, for: .widget)
        }
        .configurationDisplayName("Your Teams")
        .description("Live scores or next kickoffs for the teams you follow.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
    }
}

#Preview("Medium", as: .systemMedium) {
    NextGameWidget()
} timeline: {
    NextGameEntry.sampleFull
    NextGameEntry(date: .now, state: .noFollows)
}

#Preview("Large", as: .systemLarge) {
    NextGameWidget()
} timeline: {
    NextGameEntry.sampleFull
}

#Preview("Lock screen", as: .accessoryRectangular) {
    NextGameWidget()
} timeline: {
    NextGameEntry.sample
}
